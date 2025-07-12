#!/bin/bash

# echo "This project is not yet completed or tested and may, in this version, cause damage to your computer. Enter 'y' to confirm that you want to continue."
# read -r c
# if [ "$c" != "y" ]; then
#   exit 0
# fi

echo -e "Select a course group:\n - k5\n - ms\n - hs"
read -p "↳ " selected_course_group # TODO enforce to options

echo "Fetching courses for \"${selected_course_group}\"..."
mapfile courses <<< $(curl -s "https://accessim.org/${selected_course_group}" | grep -E "<a class=\"im-c-course-picker-link im-meta\"[^>]*>" -o)
echo -e "\nSelect a course:"
for course in "${courses[@]}"; do
  echo " - "`echo $course | grep -E "data-course=\"[^\"]*\"" -o | sed -E "s/(data-course=\")|(\")//g"`
  echo "   ⇁ https://accessim.org"`echo $course | grep -E "href=\"[^\"]*\"" -o | sed -E "s/(href=\")|(\")|(\?.*$)//g"`
done
read -p "↳ " selected_course # TODO enforce to options

echo "Fetching units for \"${selected_course}\"..."
mapfile units <<< $(curl -s "https://accessim.org"`echo "${courses[@]}" | grep "\"${selected_course}\"" | grep -E "href=\"[^\"]*\"" -o | sed -E "s/(href=\")|(\")|(\?.*$)//g"` | grep -E "<a class=\"im-c-unit-link im-meta\" [^>]*>" -o)
echo -e "\nUnits fetched:"
for unit in "${units[@]}"; do
  echo " - "`echo $unit | grep -E "data-unit=\"[^\"]*\"" -o | sed -E "s/(data-unit=\")|(\")//g"`" [ https://accessim.org"`echo $unit | grep -E "href=\"[^\"]*\"" -o | sed -E "s/(href=\")|(\")|(\?.*$)//g"`" ]"
done

for unit in "${units[@]}"; do
  unit_name=`echo $unit | grep -E "data-unit=\"[^\"]*\"" -o | sed -E "s/(data-unit=\")|(\")//g"`
  echo -e "\n# $unit_name"
  mapfile lessons <<< $(curl -s "https://accessim.org"`echo $unit | grep -E "href=\"[^\"]*\"" -o | sed -E "s/(href=\")|(\")|(\?.*$)//g"` | grep -E "<a class=\"im-c-pebble-link\" data-context=\"lesson-link\" [^>]*>" -o)
  for lesson in "${lessons[@]}"; do
    lesson_name=`echo $lesson | grep "[^/]*\">$" -o | sed -E "s/(\?).*|(\").*//g"`
    lesson_url="https://accessim.org"`echo $lesson | grep -E "href=\"[^\"]*\"" -o | sed -E "s/(href=\")|(\")|(\?.*$)//g"`"?a=teacher"
    echo "- Downloading $lesson_name [$lesson_url]..."
    wget -Ekpq "$lesson_url"
  done
done