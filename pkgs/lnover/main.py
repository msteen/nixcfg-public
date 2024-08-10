#!/usr/bin/env python

from argparse import ArgumentParser
import sys
from os import listdir, makedirs, symlink
from os.path import join, exists, isdir, dirname, basename, commonprefix
from collections import OrderedDict
import json
import errno

debug = False

def add_common_arguments(parser):
    parser.add_argument('--version', action='version', version='@version@')
    parser.add_argument('-q', '--quiet', dest='verbose', action='store_false', default=False, help='quiet output')
    parser.add_argument('-v', '--verbose', action='store_true', help='verbose output')

argument_help = {
    'src': 'source directories (e.g. /src/dir) or specific paths (e.g. src/dir:src/file/or/dir)',
    'dst': 'destination (should not already exist)',
}

parser = ArgumentParser(description='@description@.')
parser.add_argument('-t', metavar='dst', help=argument_help['dst'])
parser.add_argument('src', nargs='+', help=argument_help['src'])
parser.add_argument('dst', nargs='?', help=argument_help['dst'])
add_common_arguments(parser)
args = parser.parse_args()

if args.t is not None:
    args.dst = args.t
    del args.t
else:
    parser = ArgumentParser(description='@description@.')
    parser.add_argument('src', nargs='+', help=argument_help['src'])
    parser.add_argument('dst', help=argument_help['dst'])
    add_common_arguments(parser)
    args = parser.parse_args()

if debug: print(args)

# Prevent trailing slash.
def join_non_empty(x, y):
    return join(x, y) if y else x

def issdir(src):
    return specific and i < len(filenames)

def list_names(src):
    if specific:
        global i
        name = filenames[i]
        i += 1
        return [name]
    else:
        return listdir(src)

# Cannot set attributes on regular strings.
class SpecificStr(str):
    pass

def set_src(srcs, name, src):
    # Whether a source was specific is only relevant when considering whether an old source directory
    # should be overlaid, so we only have to mark strings.
    if type(src) is str:
        src = SpecificStr(src)
        src.specific = specific
    srcs[name] = src
    return src

def link_file(srcs, src_dir, name):
    if debug: print("link_file(srcs=%s, src_dir='%s', name='%s')" % (type(srcs), src_dir, name))
    src = join_non_empty(src_dir, name)
    old_src = srcs[name] if name in srcs else None
    if old_src and isinstance(old_src, dict) and (isdir(src) or issdir(src)):
        old_names = old_src.keys()
        new_names = list_names(src)
        if not set(old_names) <= set(new_names):
            for name in list_names(src):
                link_file(old_src, src, name)
            return
    elif old_src and not old_src.specific and isdir(old_src) and (isdir(src) or issdir(src)):
        old_names = listdir(old_src)
        new_names = list_names(src)
        if not set(old_names) <= set(new_names):
            new_srcs = set_src(srcs, name, {})
            for name in old_names:
                set_src(new_srcs, name, join_non_empty(old_src, name))
            for name in new_names:
                link_file(new_srcs, src, name)
            return
    if issdir(src):
        new_srcs = set_src(srcs, name, {})
        for name in list_names(src):
            link_file(new_srcs, src, name)
    else:
        set_src(srcs, name, src)

srcs = {}

for src in args.src:
    specific = ':' in src
    if specific:
        [src_dir, path] = src.split(':')
        filenames = path.split('/')
        i = 0
    else:
        src_dir = src
    link_file(srcs, src_dir, '')

# Sort like `ls`, by ignoring the dot in front of dotfiles.
def ignore_dot(name):
    if len(name) > 0 and name[0] is '.':
        return name[1:]
    else:
        return name

def ignore_dot_item((name, src)):
    return (ignore_dot(name), src)

def order(srcs):
    for (name, src) in srcs.items():
        if isinstance(src, dict):
            srcs[name] = order(src)
    return OrderedDict(sorted(srcs.items(), key=ignore_dot_item))

if debug: print(json.dumps(order(srcs), indent=4))

# Python 2 supported `mkdir -p` functionality.
# https://stackoverflow.com/questions/600268/mkdir-p-functionality-in-python
def mkdir_p(path):
    try:
        makedirs(path)
    except OSError as e:
        if not (e.errno == errno.EEXIST and isdir(path)):
            raise

# Only leaf directories are relevant when using `mkdir -p`.
leafs = []
def do_find_leafs(srcs, path, name):
    src = srcs[name]
    if isinstance(src, dict):
        find_leafs(src, join_non_empty(path, name))
def find_leafs(srcs, path):
    start = len(leafs)
    for name in srcs.keys():
        do_find_leafs(srcs, path, name)
    if len(leafs) == start:
        leafs.append(path)
do_find_leafs(srcs, args.dst, '')

if exists(args.dst):
    if len(leafs) == 0:
        sys.exit("Destination '%s' already exists." % args.dst)
    if not isdir(args.dst):
        sys.exit("Destination '%s' is not a directory." % args.dst)
    if listdir(args.dst):
        sys.exit("Destination '%s' is not an empty directory." % args.dst)

for dst in sorted(leafs):
    if args.verbose: print("mkdir -p '%s'" % dst)
    mkdir_p(dst)

def link(srcs, path):
    for name in sorted(srcs, key=ignore_dot):
        src = srcs[name]
        dst = join_non_empty(path, name)
        if isinstance(src, dict):
            link(src, dst)
        else:
            if args.verbose: print("ln -s '%s' '%s'" % (src, dst))
            symlink(src, dst)
link(srcs, args.dst)
