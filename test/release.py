#!/usr/bin/env python3
"""
LOCAL_RELEASE=$(cat "$DIR/../seqfu.nimble" | grep version | cut -f 2 -d = | sed 's/[" ]//g')
GH_RELEASE=$(curl -s https://api.github.com/repos/telatin/seqfu2/releases/latest  | perl -nE 'my ($tag, $val) = split /:/, $_; if ($tag=~/tag_name/) { my @tag = split /"/, $val; for my $i (@tag) { $i =~s/[^0-9.]//g; say $i if (length($i) > 2); } }')
"""

import subprocess
import sys
import json
import urllib.request
import os
import re
import hashlib
programName='SeqFu'


def eprint(*args, **kwargs):
  # import sys
  print(*args, file=sys.stderr, **kwargs)

def jsonFromURL(uri):
  operUrl = urllib.request.urlopen(uri)
  if(operUrl.getcode()==200):
    data = operUrl.read()
    jsonData = json.loads(data)
  else:
    eprint("Error receiving data", operUrl.getcode())
  return jsonData

def get_os():
  arch = subprocess.getoutput(['uname -m'])
  machine    = subprocess.getoutput(['uname -s'])
  return machine + '-' + arch

def check_gh():
  command = ['gh', 'version']
  expected_return_code = 0
  try:
    result = subprocess.run(command, stdout=subprocess.PIPE)
    if result.returncode == expected_return_code:
      return True
    else:
      return False
  except Exception as e:
    eprint(f"WARNING: checking `gh` failed:\n{e}.")
    return False

def get_last_release():
  """
  Retrieve the last release tag from Github
  """
  releaseInfo = jsonFromURL('https://api.github.com/repos/telatin/seqfu2/releases/latest')
  if 'tag_name' in releaseInfo:
    return releaseInfo['tag_name']
  else:
    eprint("ERROR: Unable to get the last release")
    quit(1)

def get_curr_release(file):
  """
  Extract the last version from Nimble
  """
  try:
    with open(file, 'r') as fd:
      content = fd.read()
      match = re.search('version\s+=\s+"(.+?)"', content)
      if match.group(1) is not None:
        return match.group(1)
      else:
        eprint(f"WARNING: Version not found in {file}")
        return ""
  except Exception as e:
    eprint(f"ERROR loading {file}:\n{e}")
    quit(1)


def get_output(bin):
  result = subprocess.run([bin], stdout=subprocess.PIPE)
  return result.stdout.decode("utf-8")

def md5sum(rootdir, filename, blocksize=2**20):
    m = hashlib.md5()
    with open( os.path.join(rootdir, filename) , "rb" ) as f:
        while True:
            buf = f.read(blocksize)
            if not buf:
                break
            m.update( buf )
    return m.hexdigest()
def list_files_md(bindir):
  """
  list files in a directory
  """
  files = os.listdir(bindir)
  md = ""
  list = {}
  for f in files:
    if f == 'seqfu':
      continue
    help_page = f"{bindir}/../docs/utilities/{f}.md"
    md5 = md5sum(bindir, f)
    list[f] = md5
    if not os.path.exists(help_page):
      eprint(f"WARNING: {help_page} not found")
      md += f" * {f}\n"
    else:
      md += " * [" + f + "]({{site.baseurl}}/utilities/" + f  + ".html)\n"
  
  return [md, list]


def get_core_utils(dir):
  md = ""
  for file in os.listdir(dir):
    module = file.split(".")
    md += f" * [seqfu {module[0]}](" + "{{site.baseurl}}/tools/" + module[0] + ".html)\n"
  return md

def init_markdown(file, release, changes, bindir):
  """
  create an empty markdown page
  """
  splash = get_output(f"{bindir}/seqfu")
  core = get_core_utils(f"{bindir}/../docs/tools/")
  #changes = ""
  utils, data = list_files_md(bindir)
  template = f"""# {programName} {release}

### Changes
{changes}

### Splash screen
```text
{splash}
```

  """
  try:
    with open(file, 'w') as f:
      print(template, file=f)
  except Exception as e:
    eprint(f"ERROR trying to write MD file to {file}:\n{e}")


def print_as_json(data, file):
  try:
    with open(file, 'w+') as fp:
      fp.write(json.dumps(data))
  except Exception as e:
    eprint(f"ERROR: Unable to print JSON to {file}:\n{e}")
    quit(1)

if __name__ == "__main__":
  import argparse
  parser = argparse.ArgumentParser(description=f'Release a new version of {programName}')
  parser.add_argument("-s", "--skip-build", help="Skip build step", action="store_true")
  parser.add_argument("-D", "--delete", help="delete the readme file", action="store_true")
  parser.add_argument("-x", "--skip-test", help="", action="store_true")
  parser.add_argument("-v", "--verbose", help="Enable verbose output", action="store_true")
  parser.add_argument("-r", "--release", help="Make release", action="store_true")
  
  args = parser.parse_args()

  if not check_gh():
    eprint("ERROR: `gh` is required.")
    quit(1)


  # Relevant variables
  last_release = get_last_release()
  script_dir = os.path.dirname(os.path.realpath(__file__))
  curr_release = get_curr_release(f"{script_dir}/../{programName.lower()}.nimble")
  basedir = f"{script_dir}/../"
  bindir = f"{basedir}/bin/"
  bin = f"{bindir}/seqfu"
  new_tag = f"v{curr_release}"
  changelog = f"{basedir}/releases/changes.md"
  os_tag = get_os()

  release_text = ""
  try:
    with open(changelog) as ch:
      release_text = ch.read()
  except Exception as e:
    eprint(f"ERROR: Change log not found {changelog}.\n{e}")
    quit(1)
  if len(release_text) == 0:
    eprint("No release notes")
    quit(1)
  if args.verbose:
    eprint(f"Last GH release:\t{last_release}")
    eprint(f"Current release:\t{new_tag}")
    eprint(f"Platform:       \t{os_tag}")

  # Build
  if not args.skip_build:
    os.chdir(f"{script_dir}/..")
    for f in os.listdir(f"{script_dir}/../bin/"):
      path = os.path.join(f"{script_dir}/../bin", f)
      eprint(f"Removing {path}")
      os.remove(path)
    build = subprocess.run(['nimble', 'build'])
    if build.returncode != 0:
      eprint("Build failed.")
      quit(1)

  # Test
  if not args.skip_test:
    subprocess.run(['bash', f'{script_dir}/../test/mini.sh'])

  release_notes = f"{script_dir}/../docs/releases/{new_tag}.md"
  release_dir = f"{basedir}/releases/"
  
  # Prepare zip
  zipfile = f"{release_dir}/zips/{programName}-{new_tag}-{os_tag}.zip"
  binaries = ['zip', '-q', '-j', zipfile]
  for file in os.listdir(bindir):
    binaries.append(os.path.join(bindir, file))
  eprint(f"Making zip file: {zipfile}")
  subprocess.run(binaries)
  
  # Check that there's a new release 
  if last_release == new_tag:
    eprint(f"ERROR: Update the release first: {new_tag} already published")
    quit(1)

  # Prepare release dir
  eprint(f"Release dir: {release_dir}")
 
  # Prepare splash screen archive
  # CORE
  splashes = {}
  try:
    for coreManPage in os.listdir(f"{basedir}/docs/tools/"):
      if coreManPage == 'README.md':
        continue
      core = coreManPage.split('.')[0]
      splash = subprocess.run([f'{bindir}/seqfu', core, '--help'], stdout=subprocess.PIPE)
      splash_screen = splash.stdout.decode('utf-8')
      splashes[f"seqfu {core}"] = splash_screen
  except Exception as e:
    quit()
    
  # UTILS:
  try:
    for utilManPage in os.listdir(f"{basedir}/docs/utilities/"):
      if utilManPage == 'README.md':
        continue
      core = utilManPage.split('.')[0]
      eprint([core, '--help'])
      splash = subprocess.run([f'{bindir}/{core}', '--help'], stdout=subprocess.PIPE)
      splash_screen = splash.stdout.decode('utf-8')
      splashes[core] = splash_screen
  except Exception as e:
    eprint(f"Error in {utilManPage}: {e}")
    quit()
  
  print_as_json(splashes, os.path.join(release_dir, f"{new_tag}.splashes.json"))

  # Generate new release document
  if not os.path.exists(release_notes) or args.delete:
    eprint(f"Generating new page: {release_notes}")
    splash = get_output(bin)

    init_markdown(release_notes, new_tag, release_text, bindir)
  
  title = f"SeqFu {new_tag}"

  status = subprocess.run(['git', 'status', '-s'], stdout=subprocess.PIPE)
  


  if len(status.stdout.decode('utf-8')) > 0:
    eprint("Uncommitted changes!")
    quit(args.release)

  if not args.release:
    quit()

  eprint("Preparing release")
  release_cmd = ['gh', 'release', 'create', new_tag, zipfile, '--title', title, '--notes-file', changelog]
  try:
    subprocess.run(release_cmd)
  except Exception as e:
    eprint(f"Failed to release: {e}.\n# {release_cmd.join(' ')}")

  try:
    os.rename(changelog, f"{basedir}/releases/{new_tag}.md")
  except Exception as e:
    eprint(f"ERROR: Unable to rename {changelog}")