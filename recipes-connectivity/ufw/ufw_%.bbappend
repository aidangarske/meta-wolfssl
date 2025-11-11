# Fix double prefix issue
do_install:append() {
    if [ -d ${D}/usr/usr ]; then
        cp -r ${D}/usr/usr/* ${D}/usr/
        rm -rf ${D}/usr/usr
    fi
}
