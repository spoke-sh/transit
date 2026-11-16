"""Installed consumers exercise the shipped server and its owned native role."""
import signal

from interfaces.inspection.inspection import System


class InstalledServer(System):
    def __init__(self, server, cli, *, object_storage=None, manual_delivery=False):
        super().__init__(None, cli, object_storage=object_storage, server=server,
                         request_timeout_ms=5000)
        self.manual_delivery = manual_delivery

    def restart_authority(self):
        if self.server and self.server.process and self.server.process.poll() is None and self.manual_delivery:
            self.delivery_signal(signal.SIGCONT)
        super().restart_authority()
        if self.manual_delivery:
            # These SDK schedules place faults before a particular delivery.
            # Stop only the actual owned courier; no public runtime option or
            # alternative authority bypasses the server's installation gates.
            self.delivery_signal(signal.SIGSTOP)

    def crash_authority(self):
        self.server.stop(kill=True)

    def __exit__(self, *exc):
        if self.server and self.server.process and self.server.process.poll() is None and self.manual_delivery:
            self.delivery_signal(signal.SIGCONT)
        super().__exit__(*exc)
