#!/bin/bash
# 导出指定iOS 多语言文件中的所有的Key，Value值
#使用  sudo chmod -R 777 /xxx/language-generate-master/produce.sh 给当前的脚本执行的权限

# 获取当前脚本文件的绝对路径
script_path=$(readlink -f "$0")
# 当前文件地址
current_dir=$(dirname "$script_path")
# keys 导出的文件地址
output_keys_dir="$current_dir/export"
# 输出的文件夹 首先输出一个 键值对的 xml 文件用于读取信息
output_keys_file="$output_keys_dir/key_values.xml"
# 无换行的xml文件
output_temp_keys_file="$output_keys_dir/key_values_temp.xml"
# 实际导出的 多语言xml文件
output_localizable_file="$output_keys_dir/localizable.xml"
# 当前输入的文件
input_path="$current_dir/source"

# 存在需要的文件
if [ -d "$input_path" ]; then
    # 判断如果输出文件夹已存在的情况删除重新创建
    if [ -d "$output_keys_dir" ]; then
        echo "${output_keys_dir}文件夹已存不需要重新创建"
    else
        mkdir -p "$output_keys_dir"
    fi

    # 生成excel能够打开的XML格式
    echo "正在根据源文件生成XML文件..."
    # 用于跟踪已经处理过的 key
    processed_keys=()

    folders=("$input_path"/*/)
    #当前文件夹内包含的多语言文件夹
    folder_count=${#folders[@]}
    #    echo "文件夹数量: $folder_count"

    # 声明头文件
    echo '<?xml version="1.0" encoding="UTF-8"?>\n<translations>' >"$output_keys_file"
    # 遍历 input_path 下的所有文件夹
    for lang_folder in "${folders[@]}"; do
        # 获取文件夹名字
        lang_folder_name=$(basename "$lang_folder")
        # 检查是否存在 Localizable.strings 文件
        strings_file="$lang_folder/Localizable.strings"
        if [ -f "$strings_file" ]; then
            # 处理将所有的 key value 写入文件夹
            while IFS='=' read -r key value || [ -n "$key" ]; do
                key=$(echo "$key" | sed -n 's/^"\([^"]*\)".*/\1/p' | sed 's/=.*//' | sed 's/\\n/\\\\n/g')
                value=$(echo "$value" | grep -vE '^\s*//' | grep -vE '^\s*/\*' | cut -d '=' -f 2 | sed 's/^[[:space:]]*//' | sed 's/"//g' | sed '/^$/d' | sed 's/;$//')
                # 如果Key 为空的情况下不执行
                if [ -z "$key" ]; then
                    continue
                fi
                # 如果 key 已经处理过，则插入到已存在的 <item> 标签中
                if [[ " ${processed_keys[@]} " =~ " ${key} " ]]; then

                    insertValue="<value key=\"$lang_folder_name\">$value</value>"
                    sed -i.bak "s|<item key=\"$key\">|<item key=\"$key\">$insertValue|" "$output_keys_file"

                else
                    echo "<item key=\"$key\">" >>"$output_keys_file"
                    echo "<value key=\"$lang_folder_name\">$value</value>" >>"$output_keys_file"
                    printf "</item>" >>"$output_keys_file"
                    processed_keys+=("$key")
                fi
            done <"$strings_file"
        else
            echo "警告: $lang_folder_name 文件夹中不存在 Localizable.strings 文件"
        fi
    done
    # 插入文件的结尾
    echo '\n</translations>' >>"$output_keys_file"
    echo "KeyValue-XML文件生成完成."

    echo "开始清除原始文件中的换行符号"
    tr -d '\n' <"$output_keys_file" >"$output_temp_keys_file"

    echo "开始执行多语言XML的生成脚本..."

    # 定义 XML 头部
    header="<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><?mso-application progid=\"Excel.Sheet\"?><Workbook xmlns=\"urn:schemas-microsoft-com:office:spreadsheet\" xmlns:o=\"urn:schemas-microsoft-com:office:office\" xmlns:x=\"urn:schemas-microsoft-com:office:excel\" xmlns:ss=\"urn:schemas-microsoft-com:office:spreadsheet\" xmlns:html=\"http://www.w3.org/TR/REC-html40\"><Worksheet ss:Name=\"Sheet1\"><Table ss:ExpandedColumnCount=\"$folder_count\"><Column ss:AutoFitWidth=\"1\" />"
    echo "$header" >"$output_localizable_file"

    # 插入第一行的数据(作为语言对应的 Key)
    echo '<Row ss:AutoFitWidth="1">' >>"$output_localizable_file"
    # 固定增加关键的Key字符串
    printf "<Cell><Data ss:Type=\"String\">Key</Data></Cell>" >>"$output_localizable_file"
    for lang_folder in "${folders[@]}"; do
        lang_folder_name=$(basename "$lang_folder")
        if [[ "$lang_folder_name" != "*" ]]; then
            printf "<Cell><Data ss:Type=\"String\">$lang_folder_name</Data></Cell>" >>"$output_localizable_file"
        fi
    done
    echo '</Row>' >>"$output_localizable_file"

    # 插入实际对应的翻译数据
    parse_xml_and_insert_values() {
        # 使用 xmllint 提取所有 item 元素，并保存到临时文件
        xmllint --xpath '//item' "$output_temp_keys_file" >items.xml
        # 读取临时文件中的 item 元素
        while read -r item_line; do
            item_xml="<?xml version=\"1.0\"?><root>$item_line</root>"
            item_key=$(echo "$item_xml" | xmllint --xpath 'string(//@key)' -)
            #        echo "输出line:$item_key"
            echo "<Row ss:AutoFitWidth=\"1\">
        " >>"$output_localizable_file"
            # 默认增加Key的值
            printf "<Cell><Data ss:Type=\"String\">$item_key</Data></Cell>" >>"$output_localizable_file"
            for lang_folder in "${folders[@]}"; do
                lang_folder_name=$(basename "$lang_folder")
                if [[ "$lang_folder_name" != "*" ]]; then
                    value=$(xmllint --xpath "string(//item[@key='$item_key']/value[@key='$lang_folder_name'])" - <<<"$item_line")
                    # 当前得到的参数为空的情况
                    if [[ -z "$value" ]]; then
                        value="(未填写)"
                    fi
                    echo "<Cell><Data ss:Type=\"String\">$value</Data></Cell>" >>"$output_localizable_file"
                fi
            done
            echo "</Row>" >>"$output_localizable_file"
        done <items.xml
    }

    #调用函数
    parse_xml_and_insert_values

    #删除创建的原始文件保留备份文件
    echo "删除临时文件..."
    rm "$output_keys_file"
    rm "$output_temp_keys_file"

    # 插入表格结束标签和工作表结束标签
    echo '</Table></Worksheet></Workbook>' >>"$output_localizable_file"
    echo "多语言XML的脚本执行完毕..."
else
    echo "文件不存在"
fi
