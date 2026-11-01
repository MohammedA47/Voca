"""Real disposable local processes; no provider executables or network."""
import json
import os
from pathlib import Path
import signal
import sys
import tempfile
import time
import unittest
from voca_controller.runner import run_process, group_live
from voca_controller.routing import select_route
from voca_controller.errors import AdapterError, UncertainOpBlocksError


class ProcessTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup)
        self.root=Path(self.tmp.name);self.seen=[]
    def run_fixture(self,code,timeout=2):
        return run_process([sys.executable,'-c',code],'static fixture',self.root,self.root/'logs',
                           lambda *a:self.seen.append(a),timeout,select_route('routine','writer'),'reviewer')
    def cleanup_group(self):
        if self.seen:
            try: os.killpg(self.seen[0][1],signal.SIGKILL)
            except ProcessLookupError: pass
            for _ in range(20):
                if not group_live(self.seen[0][1]): break
                time.sleep(.05)
    def test_successful_process_result_is_parsed_and_reaped(self):
        payload='\n'.join(map(json.dumps,[{'type':'item.completed','item':{'type':'agent_message','text':'fixture'}},{'type':'turn.completed'}]))
        result=self.run_fixture('import time;time.sleep(.1);print('+repr(payload)+')')
        self.assertEqual(result.text,'fixture');self.assertFalse(group_live(self.seen[0][1]))
    def test_timeout_ends_own_process_group(self):
        self.addCleanup(self.cleanup_group)
        with self.assertRaises(AdapterError): self.run_fixture('import time;time.sleep(30)',timeout=.2)
        self.assertFalse(group_live(self.seen[0][1]))
    def test_dead_leader_live_descendant_remains_uncertain(self):
        self.addCleanup(self.cleanup_group)
        code="import subprocess,sys,time; subprocess.Popen([sys.executable,'-c','import time;time.sleep(30)']);time.sleep(.1)"
        with self.assertRaises(UncertainOpBlocksError): self.run_fixture(code)
        self.assertTrue(group_live(self.seen[0][1]))
    def test_output_budget_failure_not_success(self):
        self.addCleanup(self.cleanup_group)
        with self.assertRaises(AdapterError): self.run_fixture("print('x'*1100000)")
    def test_nonzero_exit_never_accepts_success_text(self):
        with self.assertRaises(AdapterError): self.run_fixture("import sys;print('pass');sys.exit(1)")
