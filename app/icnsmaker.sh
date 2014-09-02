#!/bin/sh

# the sipd utility was garbling the images for some reason.
# i ended up using Icon Slate http://www.kodlian.com/apps/icon-slate
# as recommented by http://daringfireball.net/2013/01/retina_favicons
# we should make the favicon as described above too FIXME


echo "this doesn't work. see comments in script."
exit



# http://stackoverflow.com/questions/12306223/how-to-manually-create-icns-files-using-iconutil
# http://apple.stackexchange.com/questions/10666/why-setting-image-as-its-own-icon-with-sips-result-a-blurred-icon-are-there-any

mkdir build/temp.iconset
sips -s format icns -z 16 16     ../static/images/ottoicon.png --out build/temp.iconset/icon_16x16.icns
sips -s format icns -z 32 32     ../static/images/ottoicon.png --out build/temp.iconset/icon_16x16@2x.icns
sips -s format icns -z 32 32     ../static/images/ottoicon.png --out build/temp.iconset/icon_32x32.icns
sips -s format icns -z 64 64     ../static/images/ottoicon.png --out build/temp.iconset/icon_32x32@2x.icns
sips -s format icns -z 128 128   ../static/images/ottoicon.png --out build/temp.iconset/icon_128x128.icns
sips -s format icns -z 256 256   ../static/images/ottoicon.png --out build/temp.iconset/icon_128x128@2x.icns
sips -s format icns -z 256 256   ../static/images/ottoicon.png --out build/temp.iconset/icon_256x256.icns
sips -s format icns -z 512 512   ../static/images/ottoicon.png --out build/temp.iconset/icon_256x256@2x.icns
sips -s format icns -z 512 512   ../static/images/ottoicon.png --out build/temp.iconset/icon_512x512.icns
sips -s format icns -z 1024 1024  ../static/images/ottoicon.png --out build/temp.iconset/icon_512x512@2x.icns
iconutil -c icns build/temp.iconset
rm -R build/temp.iconset
cp -p build/temp.icns ../static/images/ottoicon.icns

exit
