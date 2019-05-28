#!/usr/bin/env python

import os
import re
import sys
import textwrap
import subprocess
#import simplejson as json
import json

def jsonFromFile(filename):
    jsondata = None
    with open (filename) as f:
        jsondata = json.load(f)
    return jsondata


def addBlankLines(str, n):
    if not str.endswith('\n'):
        n += 1
    return str + n * '\n'


def listNodeModules(search_dir):
    modules = []
    for dirpath, dirs, files in os.walk(search_dir, topdown=True, followlinks=False):
        dirs.sort(key=str.lower)
        files.sort(key=str.lower)
        if dirpath.endswith('/node_modules'):  # maybe we should only look for package.json
            for dir in dirs:
                modulepath = os.path.join(dirpath, dir)
                packagejson = os.path.join(modulepath, 'package.json')
                if os.path.isfile( packagejson ):
                    modules.append( os.path.join(dirpath, dir) )
    return modules


def findNodeModuleLicenses(search_dir):
    modules = listNodeModules(search_dir)
    modules.sort(key=str.lower)
    licenselist = []
    notfoundlist = []
    for module in modules:
        #print module
        jsondata = jsonFromFile( os.path.join(module, 'package.json') )
        found = False
        name = str(jsondata['name'])
        version = str(jsondata['version'])
        license = ''
        #print 'version', version
        for (key, tag) in [('license', 'License: '), ('licenses', 'License(s): ')]:
            if key in jsondata:
                def fmtLic(lic):
                    if isinstance(lic, dict):
                        if 'type' in lic and 'url' in lic and len(lic) == 2:
                            return str(lic['type']) + ' - ' + str(lic['url'])
                        elif 'type' in lic and len(lic) == 1:
                            return str(lic['type'])
                        else:
                            return str(lic)
                    else:
                        return str(lic)
                lic = jsondata[key]
                if license:
                    license += '\n'
                license += tag
                if isinstance(lic, list):
                    if len(lic) > 1:
                        for onelic in lic:
                            license += '\n    ' + fmtLic(onelic)
                    else:
                        license += fmtLic(lic[0])
                else:
                    license += fmtLic(lic)
                if len(license) > len(tag)+1:
                    found = True

        # first set should be unique, second set can be duplictive and even additional to first set
        # e.g. LICENSE.MIT and LICENSE.APACHE2 is common. But we can't just incluse all because LICENSE and License will
        # cause double license listings on case insensitive file systems
        filenamesets = [ ['LICENSE', 'License', 'license.txt', 'LICENSE.md', 'LICENCE'], ['LICENSE.MIT', 'LICENSE.APACHE2', 'COPYING'] ]
        uniqueset = True
        for filenameset in filenamesets:
            for filename in filenameset:
                licensefile = os.path.join(module, filename)
                if os.path.isfile(licensefile):
                    with open(licensefile) as f:
                        if license:
                            license = addBlankLines(license, 1)
                        license += f.read()
                    if len(license) > 2:
                        found = True
                        if uniqueset:
                            break
            uniqueset = False

        if not found:
            for filename in ['README.md', 'Readme.md', 'README.mdown', 'readme.markdown']:
                if found:
                    break
                readmefile = os.path.join(module, filename)
                if os.path.isfile( readmefile ):
                    with open(readmefile) as f:
                        readme = f.readlines()

                        licenseheader = re.compile('^###? license', re.IGNORECASE)
                        anyheader = re.compile('^###? ')
                        inlicense = False
                        for line in readme:
                            if not inlicense:
                                if licenseheader.match(line):
                                    inlicense = True
                            else:
                                if anyheader.match(line):
                                    inlicense = False
                                    break
                                else:
                                    license += line
                                    found = True

                        if not found:
                            inlicense = False
                            for line in readme:
                                if not inlicense:
                                    if line == 'LICENSE\n' or line == 'License\n':
                                        inlicense = True
                                        license += line
                                else:
                                    license += line
                                    found = True

        if found:
            licenselist.append( (module, name, '(node module)', version, license) )
        else:
            notfoundlist.append( (module, name, version) )
            #print subprocess.check_output(['ls', '-l', module])
            #for filename in ['README.md', 'Readme.md', 'README.mdown']:
            #    readmefile = os.path.join(module, filename)
            #    if os.path.isfile( readmefile ):
            #        with open(readmefile) as f:
            #            readme = f.readlines()
            #            print ''.join(readme)
        
    return (licenselist, notfoundlist)


def loadLicense(root_dir, info):
    (package, desc, version, licensefile, vercmd, verstr) = info

    # first verify the version string
    args = vercmd.split(' ')
    teststr = subprocess.check_output(args, stderr=subprocess.STDOUT, universal_newlines=True)
    teststr.strip('\n')
    teststr = teststr.split('\n')[0]
    if teststr != verstr:
        print 'error: unexpected version string for package', package, 'version', version, 'using command', vercmd
        print 'expected:', verstr
        print 'received:', teststr
        return None

    if not isinstance(licensefile, list):
        licensefile = [licensefile]

    license = ''
    for filename in licensefile:
        if not filename.startswith('/'):
            filename = os.path.join(root_dir, filename)
        if os.path.isfile(filename):
            with open(filename) as f:
                if license:
                    license = addBlankLines(license, 2)
                license += f.read()

    if len(license) < 3:
        print 'error: empty license file'
        return None

    return (None, package, desc, version, license)


def grabLicenses(root_dir, output_file):
    licenselist = []
    notfoundlist = []

    loadlist = [
        #('mpd', '"Music Player Daemon"', '0.16.3', 'dist/mpd-0.16.3/COPYING', 'mpd -V', 'mpd (MPD: Music Player Daemon) 0.16.3 '), # note ending space in verstr
        ('mongo', '"MongoDB"', '2.4.9', ['/Users/jon/otto/mongodb-osx-x86_64-2.4.9/GNU-AGPL-3.0',
                            '/Users/jon/otto/mongodb-osx-x86_64-2.4.9/THIRD-PARTY-NOTICES'], 'mongo --version', 'MongoDB shell version: 2.4.9'),
        ('node', '"node.js"', '0.8.17', '/Users/jon/otto/node-v0.8.17-darwin-x64/LICENSE', 'node -v', 'v0.8.17'),
        #('python', '"Python"', '2.7.6', '/usr/local/Cellar/python/2.7.6/LICENSE', 'python -V', 'Python 2.7.6'),
        ]

    # fatal = False
    # for info in loadlist:
    #     license = loadLicense(root_dir, info)
    #     if license:
    #         licenselist.append(license)
    #     else:
    #         fatal = True
    # if fatal:
    #     sys.exit(1)

    (nm_licenselist, nm_notfoundlist) = findNodeModuleLicenses( os.path.join(root_dir, 'node_modules') )
    licenselist.extend(nm_licenselist)
    notfoundlist.extend(nm_notfoundlist)

    (nm_licenselist, nm_notfoundlist) = findNodeModuleLicenses( os.path.join(root_dir, 'lib', 'node_modules') )
    licenselist.extend(nm_licenselist)
    notfoundlist.extend(nm_notfoundlist)

    with open(output_file, 'w') as f:
        header = """\
                  Otto uses third-party libraries or other resources that may
                  be distributed under licenses different than the Otto software.

                  In the event that I accidentally failed to list a required notice,
                  please bring it to my attention by sending email to:

                             jon@ottojukebox.com

                  The attached notices are provided for information only.
                  """
        print >>f, textwrap.dedent(header), '\n\n'

        modulesdone = []
        for (module, name, desc, version, license) in licenselist:
            if (name, desc, version) not in modulesdone:
              print >>f, "=" * 70
              print >>f, name, desc, 'version', version
              print >>f, "=" * 70
              print >>f, '\n', license, '\n\n\n'

              modulesdone.append( (name, desc, version) )

    expectedmissingnodemodulelicenses = [
        ('cookie', '0.0.4'),
        ('crc', '0.2.0'),
        ('epipebomb', '0.1.1'),
        ('fresh', '0.1.0'),
        ('fstream-ignore', '0.0.5'),
        ('inherits', '1.0.0'),
        ('promzard', '0.2.0'),
        ('range-parser', '0.0.4'),
        ('tinycolor', '0.0.1'),
        ('uglify-js', '1.2.5'),
        ('uglify-js', '1.2.6'),
        ('uglify-js', '1.3.4'),
        ('zappajs', '0.4.14'),
        ('zipstream', '0.2.1'),
    ]

    for (module, name, version) in notfoundlist:
        key = (name, version)
        if (name, version) in expectedmissingnodemodulelicenses:
            print 'license not found for', name, version, '(expected)'

    print 'wrote file', output_file

    unexpected_count = 0
    for (module, name, version) in notfoundlist:
        key = (name, version)
        if (name, version) not in expectedmissingnodemodulelicenses:
            unexpected_count+=1
            print 'error: license not found for', name, version, module
    if unexpected_count:
        print 'error:', unexpected_count, 'node_module(s) missing licenses unexpectely'
        sys.exit(1)


if __name__ == '__main__':
    if len(sys.argv) > 1:
        root_dir = sys.argv[1]
    else:
        root_dir = '/usr/local/otto'
    if len(sys.argv) == 3:
        output_file = sys.argv[2]
    else:
        output_file = 'THIRD-PARTY-NOTICES'

    grabLicenses(root_dir, output_file)
