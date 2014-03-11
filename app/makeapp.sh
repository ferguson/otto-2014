#!/bin/sh

ROOT=/usr/local/otto

if [ "$OTTO_ACTIVATE" != "$ROOT" ]; then
    echo "you need to . activate"
    exit 1
fi

cd $ROOT/app || exit

rm -rf $ROOT/app/{build,dist}

#export PATH=/usr/bin:/bin:/usr/sbin:/sbin
#unset LD_LIBRARY_PATH
#unset DYLD_FALLBACK_LIBRARY_PATH
#unset MANPATH
#unset VIRTUAL_ENV

#arch -32 python setup.py py2app $*
#arch -32 python2.7 setup.py py2app --iconfile ../static/images/ottoicon.icns
python setup.py py2app $*


RES=dist/Otto.app/Contents/Resources

if [ ! -d $RES ]; then
  echo "failed"
  exit
fi

cd $RES || exit
echo 'installing mpd'
tar -zxf $ROOT/app/mpd-0.16.3-10.7.tar.gz
mv mpd-0.16.3-10.7/lib/* lib/
mv mpd-0.16.3-10.7/bin .
rm -rf mpd-0.16.3-10.7

cd $ROOT/app || exit

#rsync -a $ROOT/lib/{node,node_modules,python2.7,glib-2.0,gettext,charset.alias} $RES/lib/

#!#rsync -a $ROOT/lib/{node,node_modules,glib-2.0,gettext,charset.alias} $RES/lib/
#!## are gettext glib-2.0 and charset.alias really needed?
#!## should i copy share and include from $ROOT? note that include overlaps
rsync -a $ROOT/lib/{node,node_modules,dtrace} $RES/lib/

rsync -a $ROOT/node_modules $RES/

scp -p /usr/local/lib/libtiff* $RES/lib

cp -p $ROOT/bin/{activate*,bsondump,chardetect,mongo*,mutagen*,ncmpc,mpc,node,node-waf} $RES/bin

ln -s ../node_modules/.bin/cake $RES/bin/
ln -s ../node_modules/.bin/coffee $RES/bin/
ln -s ../node_modules/.bin/coffeecup $RES/bin/
ln -s ../node_modules/.bin/supervisor $RES/bin/
ln -s ../node_modules/.bin/node-supervisor $RES/bin/
ln -s ../lib/node_modules/npm/bin/npm-cli.js $RES/bin/npm

cp -p ../bin/python $RES/bin
ln -s python $RES/bin/python2
ln -s python $RES/bin/python2.7
cp -p $ROOT/.Python $RES


#for f in .git LICENSE NOTES README.md TODO activate dev.sh loader.py otto* package.json reset.sh slosh start.sh static; do
for f in LICENSE NOTES README.md TODO activate dev.sh loader.py otto* package.json reset.sh slosh start.sh static; do
    echo "rsyncing $f"
    rsync -a $ROOT/$f $RES/
done

echo "done"

exit
