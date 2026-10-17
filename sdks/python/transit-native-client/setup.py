from setuptools import setup
from setuptools.command.bdist_wheel import bdist_wheel


class NativeWheel(bdist_wheel):
    def finalize_options(self):
        super().finalize_options()
        self.root_is_pure = False

    def get_tag(self):
        return 'py3', 'none', 'linux_x86_64'


setup(cmdclass={'bdist_wheel': NativeWheel})
