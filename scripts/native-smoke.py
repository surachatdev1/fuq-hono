"""Compatibility entry point; native captures must precede optional UIAutomation."""
import runpy
runpy.run_path('scripts/native-cold-start.py',run_name='__main__')
