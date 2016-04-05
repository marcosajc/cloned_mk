#!/bin/sh

set -e

slug() {
    echo $(echo $1|tr '/-' '_'|sed 's/^include_measurement_kit/mk/g')
}

gen_headers() {
    rm -f include/measurement_kit/*.hpp
    for name in $(ls include/measurement_kit/); do
        hh=include/measurement_kit/$name.hpp
        echo "// File autogenerated by \`$0\`, do not edit"                > $hh
        echo "#ifndef MEASUREMENT_KIT_$(echo $name|tr 'a-z' 'A-Z')_HPP"   >> $hh
        echo "#define MEASUREMENT_KIT_$(echo $name|tr 'a-z' 'A-Z')_HPP"   >> $hh
        for nn in $(ls include/measurement_kit/$name/); do
            echo "#include <measurement_kit/$name/$nn>"                   >> $hh
        done
        echo "#endif"                                                     >> $hh
    done

    echo "$(slug $1)_includedir = $1"
    echo "$(slug $1)_include_HEADERS = # Empty"
    for name in `ls $1`; do
        if [ ! -d $1/$name ]; then
            echo "$(slug $1)_include_HEADERS += $1/$name"
        fi
    done
    echo ""
    for name in `ls $1`; do
        if [ -d $1/$name ]; then
            gen_headers $1/$name
        fi
    done
}

gen_sources() {
    for name in `ls $2`; do
        if [ ! -d $2/$name ]; then
            if echo $name | grep -q '\.c[p]*$'; then
                echo "$1 += $2/$name"
            fi
        fi
    done
    for name in `ls $2`; do
        if [ -d $2/$name ]; then
            if [ "$2/$name" = "src/ext" ]; then
                continue  # do not descend into external sources
            fi
            gen_sources $1 $2/$name
        fi
    done
}

gen_executables() {
    for name in `ls $2`; do
        if [ ! -d $2/$name ]; then
            if echo $name | grep -q '\.c[p]*$'; then
                bin_name=$(echo $name | sed 's/\.c[p]*$//g')
                echo ""
                echo "if $3"
                echo "    $1 += $2/$bin_name"
                echo "endif"
                echo "$2/$bin_name" >> .gitignore
                echo "$(slug $2/$bin_name)_SOURCES = $2/$name"
                echo "$(slug $2/$bin_name)_LDADD = libmeasurement_kit.la"
            fi
        fi
    done
    for name in `ls $2`; do
        if [ -d $2/$name ]; then
            gen_executables $1 $2/$name $3
        fi
    done
}

get() {
  branch=$4
  [ -z "$branch" ] && branch=master
  if [ ! -d src/ext/$3 ]; then
      git clone --depth 50 -b $branch https://github.com/$1 src/ext/$3
  else
      (cd src/ext/$3 && git checkout $branch && git pull)
  fi
  (cd src/ext/$3 && git checkout $2)
}

grep -v -E "^(test|example){1}/.*" .gitignore > .gitignore.new
mv .gitignore.new .gitignore

echo "* Generating include.am"
echo "# Autogenerated by $0 on date $(date)"            > include.am
echo ""                                                >> include.am
gen_sources libmeasurement_kit_la_SOURCES src          >> include.am
echo ""                                                >> include.am
gen_headers include/measurement_kit                    >> include.am
gen_executables noinst_PROGRAMS example BUILD_EXAMPLES >> include.am
gen_executables ALL_TESTS test BUILD_TESTS             >> include.am

echo "* Updating .gitignore"
sort -u .gitignore > .gitignore.new
mv .gitignore.new .gitignore

echo "* Fetching dependencies"
get akheron/jansson v2.7-52-ge44b223 jansson
get boostorg/assert boost-1.59.0 boost/assert
get boostorg/config boost-1.59.0 boost/config
get boostorg/core boost-1.59.0-8-g3add966 boost/core
get boostorg/detail boost-1.59.0 boost/detail
get boostorg/iterator boost-1.59.0 boost/iterator
get boostorg/mpl boost-1.59.0 boost/mpl
get boostorg/predef boost-1.59.0 boost/predef
get boostorg/preprocessor boost-1.59.0 boost/preprocessor
get boostorg/smart_ptr boost-1.59.0 boost/smart_ptr
get boostorg/static_assert boost-1.59.0 boost/static_assert
get boostorg/throw_exception boost-1.59.0 boost/throw_exception
get boostorg/type_traits boost-1.59.0 boost/type_traits
get boostorg/typeof boost-1.59.0 boost/typeof
get boostorg/utility boost-1.59.0 boost/utility
get jbeder/yaml-cpp release-0.5.2-16-g97d56c3 yaml-cpp
get joyent/http-parser v2.6.0 http-parser
get measurement-kit/libevent patches-2.0 libevent patches-2.0
get measurement-kit/libmaxminddb master libmaxminddb
get philsquared/Catch v1.2.1 Catch

echo "* Running 'autoreconf -i'"
autoreconf -i
