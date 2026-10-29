import platform

from setuptools import setup
from setuptools.command.bdist_wheel import bdist_wheel


class NativeWheel(bdist_wheel):
    def finalize_options(self):
        super().finalize_options()
        self.root_is_pure = False

    def get_tag(self):
        architecture = platform.machine()
        if architecture not in ('x86_64', 'aarch64'):
            raise RuntimeError('unsupported native wheel architecture')
        return 'py3', 'none', 'linux_' + architecture


setup(cmdclass={'bdist_wheel': NativeWheel})
