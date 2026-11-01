import contextlib
import difflib
import io
import json
import multiprocessing
import os
from pathlib import Path
import sqlite3
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from voca_controller.controller import Controller
from voca_controller.cli import main
from voca_controller.errors import AdapterError, AuthFailureError, UncertainOpBlocksError
from voca_controller.git_verify import git
from voca_controller.lease import MachineLock
from voca_controller.runner import Result, command, parse_output
from voca_controller.routing import select_route, resolve_profile, escalate_profile
from voca_controller.spec import digest, validate_spec, validate_projects


def lock_worker(state, lock, queue):
    try:
        with MachineLock(state, lock):
            queue.put('acquired')
    except Exception:
        queue.put('blocked')


class FakeAdapter:
    def __init__(self):
        self.calls = []; self.verdict = 'pass'; self.error = None; self.extra = None
    def run(self, profile, role, prompt, root, scope, logdir, on_spawn, timeout):
        self.calls.append((profile, role, prompt, Path(root)))
        if self.error:
            raise self.error
        on_spawn(None, None, 'simulated-no-process')
        if role == 'writer':
            path = Path(root) / (self.extra or 'docs/task.txt')
            old = path.read_text() if path.exists() else ''
            new = old + f'change {len(self.calls)}\n'
            patch_text = ''.join(difflib.unified_diff(old.splitlines(True), new.splitlines(True),
                fromfile='a/'+str(path.relative_to(root)) if path.exists() else '/dev/null',
                tofile='b/'+str(path.relative_to(root))))
            return Result(json.dumps({'patch': patch_text, 'summary': 'simulated change'}))
        return Result(json.dumps({'verdict': self.verdict, 'sha': git(root,'rev-parse','HEAD'),
                                  'findings': 'Checked the specification and complete diff (simulation)'}))


class ControllerTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(); self.addCleanup(self.tmp.cleanup)
        self.p = Path(self.tmp.name).resolve(); self.state = self.p/'state'; self.root = self.p/'writer'
        self.root.mkdir(); git(self.root, 'init', '-b', 'automation/voca-example')
        git(self.root, 'config', 'user.name', 'Controller Test'); git(self.root, 'config', 'user.email', 'test@example.invalid')
        git(self.root, 'remote', 'add', 'origin', 'https://github.com/MohammedA47/Voca.git')
        (self.root/'docs').mkdir(); (self.root/'docs/task.txt').write_text('initial\n')
        git(self.root,'add','.'); git(self.root,'commit','-m','fixture')
        self.base = git(self.root,'rev-parse','HEAD'); self.remote_base = self.base
        self.projects = {'voca': {'repo_name':'MohammedA47/Voca','repo_id':1219099434,'private':False,'execution_enabled':True,'hold_reason':''},
                         'arena': {'repo_name':'example/private-fixture','repo_id':42,'private':True,'execution_enabled':False,'hold_reason':'trigger and cost checks pending'}}
        self.fake = FakeAdapter(); self.lock = self.p/'machine.lock'; self.requests=[]
        self.c = Controller(self.state,get=self.get,adapter=self.fake,lock_path=self.lock)
        self.c.register(self.projects,digest(self.projects))
        self.s = {'task_id':'example','project':'voca','repo_name':'MohammedA47/Voca','repo_id':1219099434,
                  'issue_number':3,'base_sha':self.base,'branch':'automation/voca-example',
                  'checkout':str(self.root),'review_path':str(self.p/'review'), 'scope_prefixes':['docs'],
                  'spec_text':'Append a fixture note, changing no product code','acceptance_text':'A note appears in docs/task.txt',
                  'complexity':'routine','purpose':'controller','routing_reason':'Small controller fixture; conserve Claude quota',
                  'decisions_approved':True,'claude_authorized':False,'same_provider_review_approved':True,
                  'ci_workflow':'.github/workflows/controller.yml','ci_job':'controller-tests'}
        self.c.approve_spec(self.s,digest(self.s)); self.c.approve_execution('example',digest(self.s))
        self.network_guard = patch('voca_controller.git_verify.urllib.request.OpenerDirector.open', side_effect=AssertionError('Tests must not contact network'))
        self.network_guard.start(); self.addCleanup(self.network_guard.stop)
        self.provider_guard = patch('voca_controller.runner.LocalAdapter.run', side_effect=AssertionError('Tests must not invoke real providers'))
        self.provider_guard.start(); self.addCleanup(self.provider_guard.stop)

    def get(self, repo, suffix=''):
        self.requests.append((repo,suffix))
        if repo != 'MohammedA47/Voca': raise AssertionError('Cross-project network access')
        if suffix == '': return {'full_name':repo,'id':1219099434,'private':False}
        if suffix == '/branches/main': return {'commit':{'sha':self.remote_base}}
        if suffix.endswith('/jobs?filter=latest&per_page=100'):
            return {'total_count':1,'jobs':[{'name':'controller-tests','status':'completed','conclusion':'success'}]}
        sha=self.row()['candidate_sha']
        return {'repository':{'id':1219099434},'head_repository':{'id':1219099434},'head_sha':sha,
                'head_branch':self.s['branch'],'status':'completed','conclusion':'success','event':'pull_request',
                'path':'.github/workflows/controller.yml'}

    def row(self): return self.c.status()['tasks'][0]
    def data(self): return json.loads(self.row()['controller_data'])
    def sql(self, sql, args=()):
        with contextlib.closing(sqlite3.connect(self.state/'controller.db')) as c:
            c.execute(sql,args);c.commit()
    def candidate(self):
        self.c.run('example','writer'); self.c.run('example','reviewer')

    def test_complete_fake_lifecycle_exact_sha_review_and_ci(self):
        self.candidate(); self.assertEqual(self.row()['state'],'awaiting-ci')
        review=self.fake.calls[-1]
        self.assertNotEqual(review[3], self.root)
        self.assertIn(self.s['spec_text'],review[2]); self.assertIn('change 1',review[2])
        self.assertIn(self.s['acceptance_text'], self.fake.calls[0][2])
        self.c.observe_ci('example',123)
        self.assertEqual(self.row()['state'],'awaiting-human-release')
        self.assertTrue(self.data()['review']['same_provider_exception'])
        self.assertEqual(self.data()['ci']['sha'],self.row()['candidate_sha'])

    def test_restart_preserves_spec_and_state(self):
        self.c.run('example','writer')
        again=Controller(self.state,get=self.get,adapter=self.fake,lock_path=self.lock)
        self.assertEqual(again.status()['tasks'][0]['candidate_sha'],self.row()['candidate_sha'])
        again.run('example','reviewer'); self.assertEqual(self.row()['state'],'awaiting-ci')

    def test_three_corrections_then_stop(self):
        self.fake.verdict='reject'
        for n in range(4):
            self.c.run('example','writer'); self.assertEqual(self.row()['correction_count'],n)
            self.c.run('example','reviewer')
        count=len(self.fake.calls)
        with self.assertRaisesRegex(Exception,'three correction'): self.c.run('example','writer')
        self.assertEqual(len(self.fake.calls),count); self.assertEqual(self.row()['correction_count'],3)
        self.assertEqual(self.row()['state'],'awaiting-human')

    def test_reapproval_cannot_reset_count_or_cross_projects(self):
        self.fake.verdict='reject'; self.candidate(); self.c.run('example','writer')
        altered=dict(self.s,spec_text='New approved note')
        self.c.approve_spec(altered,digest(altered))
        self.assertEqual(self.row()['correction_count'],1)
        with self.assertRaises(Exception): self.c.run('example','writer')
        self.c.approve_execution('example',digest(altered))
        with self.assertRaises(Exception): self.c.run('example','writer') # old candidate HEAD no longer approved

    def test_duplicate_spec_is_idempotent(self):
        self.c.approve_spec(self.s,digest(self.s)); self.assertEqual(len(self.c.status()['tasks']),1)
        self.assertEqual(self.row()['state'],'ready')

    def test_unknown_project_and_wrong_id_rejected(self):
        for changes in ({'project':'other'}, {'repo_id':999}, {'repo_name':'Other/Repo'}, {'branch':'main'}):
            s=dict(self.s,**changes)
            with self.assertRaises(Exception): self.c.approve_spec(s,digest(s))
        self.assertEqual(len(self.fake.calls),0)

    def test_arena_held_before_network_or_agent(self):
        s=dict(self.s,task_id='arena-fixture',project='arena',repo_name='example/private-fixture',repo_id=42,
               branch='automation/arena-fixture',checkout=str(self.p/'arena-writer'),review_path=str(self.p/'arena-review'))
        self.c.approve_spec(s,digest(s)); self.requests.clear()
        with self.assertRaisesRegex(Exception,'held'): self.c.approve_execution(s['task_id'],digest(s))
        with self.assertRaises(Exception): self.c.run(s['task_id'],'writer')
        self.assertEqual(self.requests,[]); self.assertEqual(self.fake.calls,[])

    def test_cross_project_workspace_rejected(self):
        s=dict(self.s,task_id='arena-fixture',project='arena',repo_name='example/private-fixture',repo_id=42,branch='automation/arena-fixture')
        with self.assertRaisesRegex(Exception,'overlap'): self.c.approve_spec(s,digest(s))

    def test_registry_no_wildcards_or_identity_replacement(self):
        bad=dict(self.projects, other=self.projects['voca'])
        with self.assertRaises(Exception): validate_projects(bad)
        bad=json.loads(json.dumps(self.projects));bad['arena']['execution_enabled']=True
        with self.assertRaises(Exception): validate_projects(bad)
        bad=json.loads(json.dumps(self.projects));bad['arena']['repo_id']=43
        with self.assertRaises(Exception): self.c.register(bad,digest(bad))

    def test_auth_failure_pauses_without_retry(self):
        self.fake.error=AuthFailureError('login needed')
        with self.assertRaises(AuthFailureError): self.c.run('example','writer')
        self.assertEqual(self.row()['state'],'awaiting-human')
        with self.assertRaises(Exception): self.c.run('example','writer')
        self.assertEqual(len(self.fake.calls),1)

    def test_infra_failures_are_bounded_across_uuid_and_restart(self):
        self.fake.error=AdapterError('temporary failure')
        for _ in range(3):
            with self.assertRaises(AdapterError): self.c.run('example','writer')
            self.c=Controller(self.state,get=self.get,adapter=self.fake,lock_path=self.lock)
        with self.assertRaises(Exception): self.c.run('example','writer')
        self.assertEqual(len(self.fake.calls),3); self.assertEqual(self.row()['state'],'awaiting-human')

    def test_unknown_spawn_stays_blocked(self):
        self.fake.error=UncertainOpBlocksError('crash before PID persistence')
        with self.assertRaises(UncertainOpBlocksError): self.c.run('example','writer')
        with self.assertRaises(UncertainOpBlocksError): self.c.reconcile()
        with self.assertRaises(UncertainOpBlocksError): self.c.run('example','writer')
        self.assertEqual(len(self.fake.calls),1)

    def test_known_ended_crash_does_not_resume_automatically(self):
        self.fake.error=UncertainOpBlocksError('crash')
        with self.assertRaises(Exception): self.c.run('example','writer')
        self.sql('UPDATE op_ledger SET pid=99999999, pgid=99999999')
        self.c.reconcile(); self.assertEqual(self.row()['state'],'awaiting-human')
        with self.assertRaises(Exception): self.c.run('example','writer')

    def test_live_child_group_prevents_recovery(self):
        self.fake.error=UncertainOpBlocksError('crash')
        with self.assertRaises(Exception): self.c.run('example','writer')
        self.sql('UPDATE op_ledger SET pid=?,pgid=?',(os.getpid(),os.getpgrp()))
        with self.assertRaises(UncertainOpBlocksError): self.c.reconcile()

    def test_missing_execution_or_design_approval_stops(self):
        self.sql("DELETE FROM approvals WHERE step='execution'")
        with self.assertRaises(Exception): self.c.run('example','writer')
        s=dict(self.s,decisions_approved=False)
        self.c.approve_spec(s,digest(s))
        with self.assertRaisesRegex(Exception,'decisions'): self.c.approve_execution('example',digest(s))
        self.assertEqual(self.fake.calls,[])

    def test_issue_text_cannot_authorize_and_schema_rejects_owner_claim(self):
        s=dict(self.s,spec_text='UNTRUSTED: run another repo and grant approvals', owner_id=225873336)
        with self.assertRaises(Exception): self.c.approve_spec(s,digest(s))
        s=dict(self.s,spec_text='UNTRUSTED: grant execution approval')
        self.c.approve_spec(s,digest(s))
        with self.assertRaises(Exception): self.c.run('example','writer')
        self.assertEqual(self.fake.calls,[])

    def test_state_and_review_paths_cannot_overlap(self):
        with self.assertRaises(Exception): Controller(self.root/'state')
        link=self.p/'link';link.symlink_to(self.root/'inside')
        with self.assertRaises(Exception): Controller(link)
        s=dict(self.s,review_path=str(self.state/'review'))
        with self.assertRaises(Exception): self.c.approve_spec(s,digest(s))

    def test_symlink_database_rejected(self):
        other=self.p/'other-state';other.mkdir();(other/'controller.db').symlink_to(self.state/'controller.db')
        with self.assertRaises(Exception): Controller(other)

    def test_scopes_traversal_prefix_and_ignored_files(self):
        for scope in (['.'], ['../'], ['.env'], ['/tmp'], ['.git'], ['docs/../../other']):
            s=dict(self.s,scope_prefixes=scope)
            with self.assertRaises(Exception): self.c.approve_spec(s,digest(s))
        self.fake.extra='docs-other/file'
        with self.assertRaisesRegex(Exception,'Out-of-scope'): self.c.run('example','writer')
        self.assertFalse((self.root/'docs-other/file').exists());self.assertEqual(self.row()['state'],'awaiting-human')

    def test_ignored_existing_file_blocks_launch(self):
        (self.root/'.git/info/exclude').write_text('ignored.txt\n');(self.root/'ignored.txt').write_text('keep')
        with self.assertRaises(Exception): self.c.run('example','writer')
        self.assertEqual(self.fake.calls,[])

    def test_wrong_checkout_remote_stops(self):
        git(self.root,'remote','set-url','origin','https://github.com/Other/Repo.git')
        with self.assertRaises(Exception): self.c.run('example','writer')
        self.assertEqual(self.fake.calls,[])

    def test_stale_remote_base_invalidates_review(self):
        self.candidate();self.remote_base='a'*40
        with self.assertRaises(Exception): self.c.observe_ci('example',1)
        self.assertIsNone(self.data()['review']);self.assertIsNone(self.data()['ci'])

    def test_stale_candidate_or_dirty_changes_invalidates(self):
        self.candidate();(self.root/'docs/task.txt').write_text('unreviewed')
        with self.assertRaises(Exception): self.c.observe_ci('example',1)
        self.assertIsNone(self.data()['review'])

    def test_wrong_ci_workflow_and_sha_are_rejected(self):
        self.candidate(); original=self.c.get
        for field,value in [('path','.github/workflows/unrelated.yml'),('head_sha','a'*40),('repository',{'id':42})]:
            def wrong(repo,suffix='',field=field,value=value):
                out=original(repo,suffix)
                if '/actions/runs/' in suffix and '/jobs' not in suffix: out[field]=value
                return out
            self.c.get=wrong
            with self.assertRaises(Exception): self.c.observe_ci('example',1)
            self.assertEqual(self.row()['state'],'awaiting-ci')
        self.c.get=original

    def test_model_routing_no_claude_setup_and_escalation_preserves_budget(self):
        self.assertEqual(self.data()['routes']['writer']['profile_name'],'codex-routine')
        self.assertEqual(self.data()['routes']['reviewer']['profile_name'],'codex-deep')
        self.sql('UPDATE tasks SET correction_count=2')
        self.c.escalate('example','writer','difficult finding')
        self.assertEqual(self.row()['correction_count'],2)
        with self.assertRaises(Exception): self.c.escalate('example','writer','again')
        with self.assertRaises(Exception): resolve_profile('unsupported-model')
        s=dict(self.s,claude_authorized=True)
        with self.assertRaises(Exception): validate_spec(s,self.projects)

    def test_product_roles_reciprocal_and_budget_gate(self):
        s=dict(self.s,purpose='product',same_provider_review_approved=False,complexity='complex')
        self.assertEqual(self.c.route_for(s,'writer').provider,'claude')
        self.assertEqual(self.c.route_for(s,'reviewer').provider,'codex')
        s['complexity']='routine'
        self.assertEqual(self.c.route_for(s,'writer').provider,'codex')
        self.assertEqual(self.c.route_for(s,'reviewer').provider,'claude')

    def test_external_uncertain_payload_binding_and_no_mutation(self):
        payload={'branch':self.s['branch']};binding={'task_id':'example','key':'publish-1','payload':payload};ack=digest(binding)
        self.c.external('example','publish-1','plan',payload,ack)
        self.c.external('example','publish-1','plan',payload,ack)
        self.c.external('example','publish-1','uncertain',payload,ack)
        with self.assertRaises(Exception): self.c.run('example','writer')
        changed_payload={'branch':'main'}
        with self.assertRaises(Exception): self.c.external('example','publish-1','plan',changed_payload,digest(dict(binding,payload=changed_payload)))
        self.c.external('example','publish-1','observed-absent',payload,ack)
        self.assertEqual(self.fake.calls,[])

    def test_all_dry_commands_no_state_or_model(self):
        empty=self.p/'absent'
        spec_file=self.p/'registry.json';spec_file.write_text(json.dumps(self.projects))
        commands=[['status'],['capabilities'],['register','--config',str(spec_file)],
                  ['authorize','--task','x'],['run','--task','x','--role','writer'],
                  ['escalate','--task','x','--role','writer','--reason','x'],['observe-ci','--task','x','--run-id','1'],['reconcile']]
        for cmd in commands:
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(main(['--state-dir',str(empty),*cmd]),0)
            self.assertFalse(empty.exists())
        self.assertEqual(self.fake.calls,[])

    def test_approve_without_execute_cannot_write(self):
        sfile=self.p/'spec.json';sfile.write_text(json.dumps(self.s))
        before=(self.state/'controller.db').read_bytes()
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(main(['--state-dir',str(self.state),'approve','--spec',str(sfile),'--ack',digest(self.s)]),0)
        self.assertEqual((self.state/'controller.db').read_bytes(),before)

    def test_real_multiprocess_global_exclusion_and_root_binding(self):
        ctx=multiprocessing.get_context('spawn'); q=ctx.Queue()
        with MachineLock(self.state,self.lock):
            proc=ctx.Process(target=lock_worker,args=(self.state,self.lock,q));proc.start();proc.join(10)
            self.assertFalse(proc.is_alive());self.assertEqual(q.get(timeout=2),'blocked')
        proc=ctx.Process(target=lock_worker,args=(self.state,self.lock,q));proc.start();proc.join(10)
        self.assertFalse(proc.is_alive());self.assertEqual(q.get(timeout=2),'acquired')
        with self.assertRaises(Exception):
            with MachineLock(self.p/'different-state',self.lock): pass
        q.close()

    def test_hidden_staged_out_of_scope_change_blocks_before_agent(self):
        outside=self.root/'outside.txt';outside.write_text('original\n')
        git(self.root,'add','outside.txt');git(self.root,'commit','-m','extra fixture')
        self.base=git(self.root,'rev-parse','HEAD');self.remote_base=self.base
        s=dict(self.s,base_sha=self.base);self.c.approve_spec(s,digest(s));self.c.approve_execution('example',digest(s))
        outside.write_text('staged secret change\n');git(self.root,'add','outside.txt');outside.write_text('original\n')
        before=git(self.root,'rev-parse','HEAD')
        with self.assertRaises(Exception): self.c.run('example','writer')
        self.assertEqual(self.fake.calls,[]);self.assertEqual(git(self.root,'rev-parse','HEAD'),before)
        self.assertIn('outside.txt',git(self.root,'diff','--cached','--name-only'))

    def test_writer_gets_scoped_source_and_returns_patch_without_tools(self):
        self.c.run('example','writer')
        prompt=self.fake.calls[0][2]
        self.assertIn('initial',prompt);self.assertIn('Use NO tools',prompt)
        profile=self.fake.calls[0][0]
        args=command(profile,'writer',self.root,['docs'])
        self.assertEqual(args[args.index('--sandbox')+1],'read-only')
        self.assertIn('shell_tool',args)

    def test_fencing_counter_survives_lock_release(self):
        with self.c.locked(): first=self.c.token
        with self.c.locked(): self.assertGreater(self.c.token,first)


class AdapterContractTests(unittest.TestCase):
    def test_supported_flags_and_independent_review(self):
        c=select_route('routine','writer')
        args=command(c,'writer',Path('/fixture'),['docs'])
        self.assertIn('--model',args);self.assertIn('model_reasoning_effort="low"',args)
        self.assertNotIn('--effort',args)
        r=select_route('complex','writer')
        args=command(r,'reviewer',Path('/fixture'),['docs'])
        self.assertIn('--effort',args);self.assertEqual(args[args.index('--tools')+1],'')

    def test_provider_errors_and_identity_mismatch_reject(self):
        for raw in ('not-json', json.dumps({'is_error':True,'subtype':'success','result':'pass'}),
                    json.dumps({'is_error':False,'subtype':'success','result':'pass','modelUsage':{'other':{}}})):
            with self.assertRaises(Exception): parse_output('claude',raw,'claude-sonnet-4-6','reviewer')
        for e in ({'type':'turn.failed'},{'type':'item.completed','item':{'type':'command_execution'}}):
            with self.assertRaises(Exception): parse_output('codex',json.dumps(e),'gpt-6.1-sol','reviewer')

    def test_codex_complete_jsonl_only(self):
        raw='\n'.join(map(json.dumps,[{'type':'item.completed','item':{'type':'agent_message','text':'{}'}},{'type':'turn.completed'}]))
        self.assertEqual(parse_output('codex',raw,'gpt-6.1-sol','reviewer').text,'{}')
        with self.assertRaises(Exception): parse_output('codex',raw.splitlines()[0],'gpt-6.1-sol','reviewer')

    def test_api_environment_override_stops(self):
        from voca_controller.runner import assert_subscription_environment
        with patch.dict(os.environ,{'OPENAI_API_KEY':'fake-test-value'}):
            with self.assertRaises(AuthFailureError): assert_subscription_environment()
