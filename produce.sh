#!/bin/bash
#使用sudo chmod -R 777 xxx.sh 给当前的脚本执行的权限

#读取CSV文件并且将其转为XML数据文件
input_file='file.csv'
#模板文件
template_file='template.xml'
#生成的文件夹
produce_file='produce'
output_file_name="${produce_file}/international_writing.xml"


#iOS的变量
ios_localizble_name='Localizable.strings'
ios_zh_folder="${produce_file}/iOS/zh.lproj"
ios_en_folder="${produce_file}/iOS/en.lproj"
ios_zh_folder_path="${ios_zh_folder}/${ios_localizble_name}"
ios_en_folder_path="${ios_en_folder}/${ios_localizble_name}"

#Android 的变量
android_localizble_name='strings.xml'
android_zh_folder="${produce_file}/Android/values-zh"
android_en_folder="${produce_file}/Android/values-en"
android_zh_folder_path="${android_zh_folder}/${android_localizble_name}"
android_en_folder_path="${android_en_folder}/${android_localizble_name}"
android_xml_header='<?xml version=\"1.0\" encoding=\"UTF-8\" ?>'
android_xml_srouce_header=' <resources>'
android_xml_srouce_end=' </resources>'

if [ -d $produce_file ]; then
rm -r $produce_file
else
echo "文件夹不存在，创建文件夹"
fi
#创建生产的文件夹
mkdir -p $produce_file

# 跳过标题行
#IFS=',' read -r _ zh en < "$input_file"
# 打开CSV文件
exec 3<"$input_file"
# 跳过CSV文件的第一行（标题行）
IFS=',' read -r _ _ _ <&3
# 初始化一个标志，表示是否已经处理过至少一行数据
first_line=true

# 读取 CSV 文件中的每一行，并生成 XML 内容
while IFS=',' read -r key zh en; do
if ! $first_line; then
# 读取 XML 模板，并替换占位符  （| tr -d '\n'）删除格式中的换行符号
xml=$(cat $template_file | sed "s#<key>#$key#g;s#<ZH>#$zh#g;s#<english>#$en#g;")
echo "$xml"
fi
first_line=false
done < file.csv > $output_file_name
# 关闭CSV文件描述符
exec 3<&-

sed -i "" "s/\r<\/English><\/record>/<\/English><\/record>/g" $output_file_name


#读取 XML 文件将其转为对应的 国际化文件

#创建iOS工程的文件
mkdir -p $ios_zh_folder
mkdir -p $ios_en_folder

#开始创建Android 工程的文件
mkdir -p $android_zh_folder
echo $android_xml_header >> $android_zh_folder_path
echo $android_xml_srouce_header >> $android_zh_folder_path

mkdir -p $android_en_folder
echo $android_xml_header >> $android_en_folder_path
echo $android_xml_srouce_header >> $android_en_folder_path


echo "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>" > strings.xml
echo "<resources>" >> strings.xml

# 读取文件并生成国际化内容
cat $output_file_name | while IFS= read -r line; do
if [[ $line == *"<record>"* ]]; then
key=$(echo "$line" | sed -n 's/.*<Key>\([^<]*\)<\/Key>.*/\1/p')
zh_value=$(echo "$line" | sed -n 's/.*<SimplifiedChinese>\(.*\)<\/SimplifiedChinese>.*/\1/p')
en_value=$(echo "$line" | sed -n 's/.*<English>\(.*\)<\/English>.*/\1/p')
# 生成iOS国际化内容
echo "\"$key\" = \"$zh_value\";" >> $ios_zh_folder_path
echo "\"$key\" = \"$en_value\";" >> $ios_en_folder_path
echo "    <string name=\"$key\">$zh_value</string>" >> $android_zh_folder_path
echo "    <string name=\"$key\">$en_value</string>" >> $android_en_folder_path
fi
done

#当前内容只为Android 添加
echo $android_xml_srouce_end >> $android_zh_folder_path
echo $android_xml_srouce_end >> $android_en_folder_path

# 结束国际化文件

