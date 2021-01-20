# Maintainer: Drew DeVault <phoepsilonix@gmail.com>
pkgname=ibus-mozc
pkgver=2.26.4248.102
pkgrel=0
pkgdesc="Mozc engine for IBus - Client of the Mozc input method"
url="https://github.com/phoepsilonix/mozc"
arch="all !s390x !mips !mips64" # ibus needs librsvg which isn't available on s390x
license="The BSD 3-Clause License"
depends="ibus"
makedepends="
	ibus-dev
	qt5-qtbase-dev
	gtk+2.0-dev
	py3-core-api
	samurai
	pkgconf
	git
	clang
"
source="https://gitlab.com/phoep/mozc/-/jobs/974012190/artifacts/raw/ibus-mozc.tar.gz"
subpackages=""
# mozc tests require a running X server
options="check"

build() {
	cd src
	python3 build_mozc.py gyp
	python3 build_mozc.py build -c Release package
}

package() {
	SRC=src/src/out_linux/Release
	DATA=src/src/data/images/unix

	DST_LIB=$pkgdir/usr/lib/mozc
	DST_DATA=$pkgdir/usr/share/ibus-mozc

	install -m 00755 -D $SRC/ibus_mozc      /usr/lib/ibus-mozc/ibus-engine-mozc
	install -m 00755 -D $SRC/mozc_renderer  $DST_LIB/mozc_renderer
	install -m 00755    $SRC/mozc_server    $DST_LIB/mozc_server
	install -m 00755    $SRC/mozc_tool      $DST_LIB/mozc_tool
	install -m 00644 -D $SRC/gen/unix/ibus/mozc.xml  /usr/share/ibus/component/mozc.xml

	install -m 00644 -D $DATA/ui-alpha_full.png  $DST_DATA/alpha_full.png
	install -m 00644    $DATA/ui-alpha_half.png  $DST_DATA/alpha_half.png
	install -m 00644    $DATA/ui-dictionary.png  $DST_DATA/dictionary.png
	install -m 00644    $DATA/ui-direct.png      $DST_DATA/direct.png
	install -m 00644    $DATA/ui-hiragana.png    $DST_DATA/hiragana.png
	install -m 00644    $DATA/ui-katakana_full.png  $DST_DATA/katakana_full.png
	install -m 00644    $DATA/ui-katakana_half.png  $DST_DATA/katakana_half.png
	install -m 00644    $DATA/ime_product_icon_opensource-32.png  $DST_DATA/product_icon.png
	install -m 00644    $DATA/ui-properties.png  $DST_DATA/properties.png
	install -m 00644    $DATA/ui-tool.png  $DST_DATA/tool.png

}
sha512sums="49d904eb2b96be1a2a10fcfcfb60a6b5b37c0a79c4181578720d15a09fc33d366a6bed24760283a8618e418ccba461f15cf503e3ab566ed113a31532237ee05c  ibus-mozc.tar.gz"
