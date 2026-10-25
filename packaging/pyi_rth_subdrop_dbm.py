# PyInstaller runtime hook — ensure a dbm backend exists if something still opens dbm.
import sys

if getattr(sys, "frozen", False):
    try:
        import dbm.dumb  # noqa: F401
    except ImportError:
        pass
