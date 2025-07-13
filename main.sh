#!/bin/bash

# Functions

extract_html_tag () {
  # $1 - the tag to extract data from
  # $2 - the html element in text form
  echo `echo $2 | grep -E "${1}=\"[^\"]*\"" -o | sed -E "s/(${1}=\")|(\")|(\?.*$)//g"`
}

curl_then_sift () {
  # $1 - the link (without https://accessim.org)
  # $2 - the contents of the 'class' tag to sift
  # $3 - the additional tags (with space at start)
  local r=$(curl -s "https://accessim.org${1}" | grep -E "<a class=\"${2}\"${3}[^>]*>" -o)
  echo "$r"
}

valid () {
  # $1 - option selected (string)
  # $2 - options in format |o1|o2|o3|
  echo $2 | grep "|$(echo $1 | sed 's/|//g')|" > /dev/null
  if [[ "$?" != "0" ]]; then echo "Option '$1' not in options $2"; exit 1; fi
}

url_to_file_location () {
  # $lesson_url - url in format "https://accessim.org"`extract_html_tag "href" "$lesson"`"?a=teacher"
  echo `echo $lesson_url | sed 's/https\:\//./'`".html"
}

# cowsay im-archiver
echo " _____________"
echo "< im-archiver >"
echo " -------------"
echo "        \\  ^__^"
echo "         \\ (oo)\_______"
echo "           (__)\       )\/\\"
echo "               ||----w |"
echo "               ||     ||"

# Select course group

echo -e "Select a course group:\n - k5 (K-5)\n - ms (6-8)\n - hs (9-12)"
read -p "↳ " selected_course_group 
valid "$selected_course_group" '|k5|ms|hs|'

# Select course

echo "Fetching courses for \"${selected_course_group}\"..."
mapfile courses <<< `curl_then_sift "/$selected_course_group" "im-c-course-picker-link im-meta"`

courses_select_format="|"
echo -e "\nSelect a course:"
for course in "${courses[@]}"; do
  echo " - "`extract_html_tag "data-course" "$course"`
  courses_select_format+=`extract_html_tag "data-course" "$course"`"|"
  echo "   ⇁ https://accessim.org"`extract_html_tag "href" "$course"`
done
read -p "↳ " selected_course # TODO enforce to options
valid "$selected_course" "$courses_select_format"

# Fetch units for course

echo "Fetching units for \"${selected_course}\"..."

selected_course_html=`echo "${courses[@]}" | grep "data-course=\"${selected_course}\""`
selected_course_link=`extract_html_tag "href" "$selected_course_html"`

# Show units

mapfile units <<< `curl_then_sift "$selected_course_link" "im-c-unit-link im-meta"`
echo -e "\nUnits fetched:"
for unit in "${units[@]}"; do
  echo " - "`extract_html_tag "data-unit" "$unit"`" [ https://accessim.org"`extract_html_tag "href" "$unit"`" ]"
done

# Loop through units and download the lessons in each of them

mkdir accessim.org/assets -p

for unit in "${units[@]}"; do
  unit_name=`extract_html_tag "data-unit" "$unit"`
  unit_url=`extract_html_tag "href" "$unit"`
  echo -e "\n# $unit_name"
  mapfile lessons <<< `curl_then_sift "$unit_url" "im-c-pebble-link" ' data-context="lesson-link"'`
  for lesson in "${lessons[@]}"; do
    lesson_name=`echo $lesson | grep "[^/]*\">$" -o | sed -E "s/(\?).*|(\").*//g"`
    lesson_url="https://accessim.org"`extract_html_tag "href" "$lesson"`"?a=teacher"
    echo " - $lesson_name [$lesson_url]"

    echo "  ↳ Downloading webpage..."
    wget -Ekpq "$lesson_url"

    echo "  ↳ Downloading assets..."
    mapfile bad_links <<< $(grep -oE 'src=\"https\:\/\/cms-assets.illustrativemathematics.org[^"]*\"' $(url_to_file_location))
    for link in "${bad_links[@]}"; do
      curl -s --stderr /dev/null `extract_html_tag src $link` -o ./accessim.org/assets/`echo $link | grep -E "[^/]*\"$" -o | grep "[^\"]*" -o`
    done

    echo "  ↳ Setting up assets..."
    sed -i 's/src=\"https\:\/\/cms-assets.illustrativemathematics.org\//src=\"..\/..\/..\/..\/assets\//g' `url_to_file_location`

    echo "  ↳ Renaming file..."
    mv `url_to_file_location` `url_to_file_location | grep -o "^[^\?]*"`".html"
  done
done

echo "!!! Your files are in $(pwd)"`echo $lesson_url | grep -E "\/accessim.org\/([^\/]*\/){2}" -o`