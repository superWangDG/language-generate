
#!/bin/bash
# 导出指定iOS 多语言文件中的所有的Key，Value值
# 注意:脚本无法识别\n 的情况，如果源文件有\n的字符情况请先转为其他识别字符，之后手动替换
#使用  sudo chmod -R 777 /xxx/XML-Generation-iOS-Strings.sh 给当前的脚本执行的权限

# 获取当前脚本文件的绝对路径
script_path=$(readlink -f "$0")
# 当前文件地址
current_dir=$(dirname "$script_path")
# keys 导出的文件地址
output_strings_dir="$current_dir/export"

is_auto_file=""

while true; do
    # 提示用户输入
    read -p "是否使用脚本配置的文件(file.csv),需要将文件放置在脚本的同级目录下,输入Y使用N将会使用用户自定义的文件：" is_auto_file
    
    # 将输入转换为大写
    is_auto_file=$(echo "$is_auto_file" | tr '[:lower:]' '[:upper:]')
    
    # 检查输入是否是 "Y" 或 "N"
    if [[ "$is_auto_file" == "Y" || "$is_auto_file" == "N" ]]; then
        break  # 如果输入是 "Y" 或 "N"，则跳出循环
    else
        echo "输入的参数只能是Y或者为N"
    fi
done


if [[ "$is_auto_file" == "Y" ]]; then
input_path="file.csv"
else
read input_path
fi

if [[ "$input_path" == */* ]]; then
    # 如果包含路径分隔符，直接使用 input_path
    full_path="$input_path"
else
    # 如果不包含路径分隔符，拼接 current_dir 和 input_path
    full_path="$current_dir/$input_path"
fi

# 当前文件不存在 退出当前脚本的执行
if [ ! -f "$full_path" ]; then
    echo "$full_path 文件不存在."
    exit 1
fi

full_path_temp="${full_path}.tmp"
# 查找原始文件中的特殊符号替换成为能够处理的符号
sed 's/&/^^/g' "$full_path" > "$full_path_temp"
sed 's/\\n/\/\/n/g' "$full_path_temp" > "${full_path}.n.tmp"
mv "${full_path}.n.tmp" "$full_path_temp"

# 插入数据到文件中 $1文件地址 $2需要插入的数据列表 $3文件下标索引(如果不是批量的情况传入参数0) $4是否是iOS多语言的生成(true 或 false)
inset_string_to_flie() {
        # 初始化当前的文本
#        echo "" > "$1"
#        echo "正在写入文件:$1，当前文件所属下标$3"
        
        # 逐行读取文件内容
        while IFS= read -r line; do
            IFS=',' read -r -a line_fields <<< "$line"
            lines=()
            currentElement=""
            isAppend=false
            for ((j = 0; j < ${#line_fields[@]}; j++)); do
                item_value="${line_fields[j]}"
                if [[ $item_value == \"* ]]; then
                    currentElement=$item_value
                    isAppend=true
                fi
                if [[ $item_value == *\" ]]; then
                    currentElement+=$item_value
                    item_value=$currentElement
                    isAppend=false
                fi
                if ! $isAppend; then
                    lines+=("$item_value")
                    currentElement=""
                fi
            done
            value=${lines[$3]}
            content=""
            
            if [[ "$value" =~ ^\".*\"$ ]]; then
                value="${value#\"}"   # 去除开头的双引号
                value="${value%\"}"   # 去除结尾的双引号
            fi
            
            if "$4" == true; then
                # 当前需要转换的是iOS文件
                content="\"${lines[0]}\" = \"${value}\";"
            else
                content="\t<string name=\"${lines[0]}\">${value}</string>"
            fi
            # 拼接数据
            echo "$content" >> "$1"
        done <<< "$2"
        
        out_file="$1"
        # 将文件开头替换的字符串替换回原始的字符串
        sed 's/\^\^/\&/g' "$out_file" > "$out_file.tmp"
        mv "$out_file.tmp" "$out_file"
        sed 's/\/\/n/\\n/g' "$out_file" > "${out_file}.n.tmp"
        mv "${out_file}.n.tmp" "$out_file"
        
        echo "生成完成地址:$1"
}


android_folder_line=$(awk -F ',' 'NR==1 {print $0}' "$full_path_temp")
android_file_line=$(awk -F ',' 'NR==2 {print $0}' "$full_path_temp")
ios_folder_line=$(awk -F ',' 'NR==3 {print $0}' "$full_path_temp")
ios_file_line=$(awk -F ',' 'NR==4 {print $0}' "$full_path_temp")

IFS=',' read -r -a android_folders <<< "$android_folder_line"
IFS=',' read -r -a android_files <<< "$android_file_line"
IFS=',' read -r -a ios_folders <<< "$ios_folder_line"
IFS=',' read -r -a ios_files <<< "$ios_file_line"

echo "开始生成android多语言文件"

if [[ "${android_folders[0]}" =~ "Android Folder Name" && "${android_files[0]}" =~ "Android File Name" ]]; then
    for ((i = 1; i < ${#android_folders[@]}; i++)); do
#        echo "处理其他数据：${android_folders[i]},下标$i"
        #得到安卓文件夹的地址
        android_folder="$output_strings_dir/Android/${android_folders[i]}"
        android_file="$android_folder/${android_files[1]}"
        # 创建文件夹，并且创建文件
        if [ ! -d "$android_folder" ]; then
            mkdir -p "$android_folder"
        fi
        # 遍历循环将多语言的信息插入对应的文件中
        data_resource=$(awk -F ',' 'NR>=6 {print $0}' "${full_path_temp}")
        echo '<?xml version=\"1.0\" encoding=\"UTF-8\" ?>' > "$android_file"
        inset_string_to_flie "$android_file" "$data_resource" $i false
        echo '<resources>' >> "$android_file"
    done
else
    echo "Android 文件夹创建失败，格式错误。"
fi

echo "开始生成iOS多语言文件"
#echo "输出当前行的数据:$frist_line\n${parts[0]}"
if [[ ${ios_folders[0]} =~ "iOS Folder Name" && ${ios_files[0]} =~ "iOS File Name" ]]; then
    for ((i = 1; i < ${#ios_folders[@]}; i++)); do
        #得到iOS文件夹的地址
        ios_folder="$output_strings_dir/iOS/${ios_folders[i]}"
        ios_file="$ios_folder/${ios_files[1]}"
        
#        echo "输出文件夹的名称:${ios_folders[i]}"
        # 创建文件夹，并且创建文件
        if [ ! -d "$ios_folder" ]; then
            mkdir -p "$ios_folder"
        fi
#        echo "测试输出创建的文件夹:${ios_folders[i]}"
        
        echo "" > $ios_file
        # 遍历循环将多语言的信息插入对应的文件中
        data_resource=$(awk -F ',' 'NR>=6 {print $0}' "${full_path_temp}")
        # 使用函数 插入数据源
        inset_string_to_flie "$ios_file" "$data_resource" $i true
    done
    echo "iOS使用CSV生成多语言文件完成!"
else
    echo "iOS 文件夹创建失败，格式错误。"
fi

# 删除临时文件
rm "$full_path_temp"



