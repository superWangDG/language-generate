
#!/bin/bash

# 将统计目录中指定的文件夹内的代码多语言化


# 定义正则表达式
#pattern='[^"]*[\u4E00-\u9FA5]+[^"\n]*?'
pattern='[^"]*[一-龥]+[^"\n]*'

root_folder='jiangti'
#国际化 key value 文件
#ios_localizable_path="${root_folder}\zh-Hans.lproj\Localizable.strings"
ios_localizable_path="Localizable.strings"
#在iOS 中国际化的通用方法名
ios_localizable_func_name='fdString'

#sed -i '' 's/登录成功.../login_seccuss/g' jiangti/Login/LoginAccessAndpasswordViewController.swift
echo $ios_localizable_path

# 遍历文件夹中的文件，找到所有.swift文件并处理
find "$root_folder" -type f -name "*.swift" | while read -r file; do
  if [[ -f "$file" ]]; then
#    echo "当前正在处理的文件:$file"
      echo "正在修改${file}文件的数据..."
     matches=$(grep -oE "$pattern" "$file")
    for match in $matches; do
#      escaped_match=$(echo "$match" | sed 's/\(/\\\(/g; s/\)/\\\)/g')
     escaped_match=$(sed 's/[][()\.^$?*+()]/\\&/g' <<< "$match")
#     echo "输出当前文件的Key值:$escaped_match"
      # 获取匹配字符串左侧的Key
      key=$(grep -oE "\"[^\"]+\"" $ios_localizable_path | grep -m 1 "$escaped_match" | sed 's/"//g')
      # 当前得到了.swift文件中的中文 作为Key
#      echo "输出当前文件的Key值:$match"
      # 使用 sed 命令对圆括号进行转义
    
      if [[ -n "$key" && "$key" != " = " ]] ; then
#            echo "获取key成功:$key"
        exit_flag=false
        for item_file in $ios_localizable_path; do
            if [[ -f "$item_file" ]]; then
                # 读取文件内容并逐行处理
                while IFS= read -r line; do
                    # 使用正则表达式匹配每一行中的键值对
                    if [[ $line =~ \"(.*)\"[[:space:]]*=[[:space:]]*\"(.*)\" ]]; then
                        itemKey="${BASH_REMATCH[2]}"
                        itemValue="${BASH_REMATCH[1]}"

                        if [[ $itemKey == $key ]]; then
#                            echo "查到指定的文件退出本次查找的循环:$key=$itemValue"
                            # 此处的逻辑为 将当前文件 key 的内容替换为 value 的值
                            file_filter=${file#*/}
                            # 判断当前的字符串是否被国际化的字符串包含，如果包含情况直接替换否则 增加包含国际化的方法
                            replaceKey="$ios_localizable_func_name(\"$key\")"
                            replaceValue="$ios_localizable_func_name(\"$itemValue\")"
                            updateString=""
                            
                            if grep -q "$replaceKey" "$file"; then
                                # 当前的字符串已经包含了 国际化的标识
                                sed -i '' "s/$key/$itemValue/g" $file
                           
                            updateString="s/$key/$itemValue/g"
#                                echo "当前修改的字符串"
#                            echo "输出当前的内容11:$updateString"
                            else
#                                sed -i '' "s/\"$key\"/$ios_localizable_func_name(\"$itemValue\")/g" $file
                            updateString="s/\"$key\"/$ios_localizable_func_name(\"$itemValue\")/g"
#                                                        echo "输出当前的内容22:$updateString"
                            fi
                            
                            
                            sed -i '' $updateString $file
                            # 设置退出标志为 true
                            exit_flag=true
                            break
                        fi
                        # 退出 while 循环
#                        break
                    fi
                done < "$item_file"
                # 检查退出标志，如果为 true，则退出 for 循环
                if [[ $exit_flag == true ]]; then
#                    echo "退出循环"
                    break
                fi
            fi
        done
#        echo "当前正在处理的key:$key"
      fi
    done
  fi
done


