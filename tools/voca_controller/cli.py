"""On-demand CLI. Every mutation/agent call requires --execute."""
import argparse
import json
from dataclasses import asdict
from .controller import Controller
from .routing import PROFILE_CATALOG, CATALOG_VERSION
from .spec import read_json, validate_projects, validate_spec, digest


def parser():
    p = argparse.ArgumentParser(prog='python -m voca_controller')
    p.add_argument('--state-dir', required=True, help='One canonical directory outside all checkouts')
    sub = p.add_subparsers(dest='command', required=True)
    sub.add_parser('status')
    sub.add_parser('capabilities')
    reg = sub.add_parser('register'); reg.add_argument('--config', required=True); reg.add_argument('--ack')
    app = sub.add_parser('approve'); app.add_argument('--spec', required=True); app.add_argument('--ack')
    auth = sub.add_parser('authorize'); auth.add_argument('--task', required=True); auth.add_argument('--ack')
    run = sub.add_parser('run'); run.add_argument('--task', required=True); run.add_argument('--role', choices=['writer','reviewer'], required=True); run.add_argument('--timeout', type=int, default=180)
    route = sub.add_parser('route'); route.add_argument('--spec', required=True)
    esc = sub.add_parser('escalate'); esc.add_argument('--task', required=True); esc.add_argument('--role', choices=['writer','reviewer'], required=True); esc.add_argument('--reason', required=True)
    ci = sub.add_parser('observe-ci'); ci.add_argument('--task', required=True); ci.add_argument('--run-id', type=int, required=True)
    sub.add_parser('reconcile')
    ext = sub.add_parser('external'); ext.add_argument('--task', required=True); ext.add_argument('--key', required=True); ext.add_argument('--action', choices=['plan','uncertain','observed-absent','observed-succeeded'], required=True); ext.add_argument('--payload', required=True, help='Local JSON file'); ext.add_argument('--ack')
    for name, command in sub.choices.items():
        if name not in ('status','capabilities','route'):
            command.add_argument('--execute', action='store_true')
    return p


def main(argv=None):
    args = parser().parse_args(argv)
    try:
        c = Controller(args.state_dir)
        execute = getattr(args, 'execute', False)
        cmd = args.command
        if cmd == 'status':
            result = c.status()
        elif cmd == 'capabilities':
            result = {'catalog_version': CATALOG_VERSION, 'profiles': PROFILE_CATALOG,
                      'source': 'Previously observed local client selections; no quota/model probe performed',
                      'claude_setup_calls': 'disabled', 'background_execution': False}
        elif cmd == 'register':
            data = validate_projects(read_json(args.config))
            result = c.register(data, args.ack) if execute else {'dry_run': True, 'digest': digest(data), 'projects': sorted(data)}
        elif cmd in ('approve','route'):
            projects = {p['key']: json.loads(p['content']) for p in c.status()['projects']}
            s = validate_spec(read_json(args.spec), projects)
            result = {'dry_run': True, 'digest': digest(s), 'routes': {r: asdict(c.route_for(s,r)) for r in ('writer','reviewer')}}
            if cmd == 'approve' and execute:
                result = c.approve_spec(s, args.ack)
        elif cmd == 'external':
            payload = read_json(args.payload)
            expected = digest({'task_id': args.task, 'key': args.key, 'payload': payload})
            result = c.external(args.task,args.key,args.action,payload,args.ack) if execute else {'dry_run': True, 'digest': expected, 'action': args.action}
        elif not execute:
            result = {'dry_run': True, 'command': cmd, 'message': 'No database, network or agent mutation performed'}
        elif cmd == 'authorize': result = c.approve_execution(args.task,args.ack)
        elif cmd == 'run': result = c.run(args.task,args.role,args.timeout)
        elif cmd == 'escalate': result = c.escalate(args.task,args.role,args.reason)
        elif cmd == 'observe-ci': result = c.observe_ci(args.task,args.run_id)
        elif cmd == 'reconcile': result = c.reconcile()
        else: raise ValueError('Unsupported command')
        print(json.dumps(result, indent=2)); return 0
    except Exception as exc:
        print(json.dumps({'error': type(exc).__name__, 'message': str(exc)})); return 1


if __name__ == '__main__':
    raise SystemExit(main())
