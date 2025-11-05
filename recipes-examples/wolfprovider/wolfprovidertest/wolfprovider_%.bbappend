WOLFPROVIDER_TEST_DIR = "${B}/test/.libs"
WOLFPROVIDER_TEST = "unit.test"
WOLFPROVIDER_TEST_YOCTO = "wolfprovidertest"
WOLFPROVIDER_INSTALL_DIR = "${D}${bindir}"

python () {
    wolfprovider_test_dir = d.getVar('WOLFPROVIDER_TEST_DIR', True)
    wolfprovider_test = d.getVar('WOLFPROVIDER_TEST', True)
    wolfprovider_test_yocto = d.getVar('WOLFPROVIDER_TEST_YOCTO', True)
    wolfprovider_install_dir = d.getVar('WOLFPROVIDER_INSTALL_DIR', True)

    bbnote = 'bbnote "Installing wolfProvider Tests"\n'
    installDir = 'install -m 0755 -d "%s"\n' % (wolfprovider_install_dir)
    cpTest = 'if [ -f "%s/%s" ]; then cp "%s/%s" "%s/%s"; fi\n' % (wolfprovider_test_dir, wolfprovider_test, wolfprovider_test_dir, wolfprovider_test, wolfprovider_install_dir, wolfprovider_test_yocto)

    d.appendVar('do_install', bbnote)
    d.appendVar('do_install', installDir)
    d.appendVar('do_install', cpTest)
}
