#
SRC=src/out_linux/Release
DATA=src/data/images/unix

#
DST_LIB=/usr/lib/mozc
DST_DATA=/usr/share/ibus-mozc

install -m 00644 -D $SRC/gen/unix/ibus/mozc.xml  /usr/share/ibus/component/mozc.xml
install -m 00755 -D $SRC/ibus_mozc      /usr/lib/ibus-mozc/ibus-engine-mozc
install -m 00755 -D $SRC/mozc_renderer  $DST_LIB/mozc_renderer
install -m 00755    $SRC/mozc_server    $DST_LIB/mozc_server
install -m 00755    $SRC/mozc_tool      $DST_LIB/mozc_tool

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

