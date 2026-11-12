#!/bin/bash
set -e

GO_VERSION=1.24

WORK_DIR=`cd $(dirname "$0")/../..;pwd`

cd $WORK_DIR

mkdir -p external/package

envoy_repos=("go-control-plane" "envoy")

for repo in ${envoy_repos[@]}; do
    if [ -e external/$repo ];then
        continue
    fi
    cp -RP envoy/$repo  external/$repo
    cd external/$repo
    echo "gitdir: /parent/.git/modules/envoy/$repo" > .git
    cd $WORK_DIR
done

istio_repos=("api" "client-go" "pkg" "istio" "proxy")

for repo in ${istio_repos[@]}; do
    if [ -e external/$repo ];then
        continue
    fi
    cp -RP istio/$repo external/$repo
    cd external/$repo
    echo "gitdir: /parent/.git/modules/istio/$repo" > .git
    cd $WORK_DIR
done

TARGET_FILE="external/istio/pilot/pkg/model/extensions.go"

if [ -f "$TARGET_FILE" ]; then
    echo "Patching $TARGET_FILE..."

    # 检查是否已经打过补丁。
    # 正则 ^[[:space:]]*wasmConfig 表示以空白字符开头，直接接 wasmConfig，这样就能排除掉 // 注释行
    if ! grep -qE "^[[:space:]]*wasmConfig\.FailOpen = plugin\.FailStrategy" "$TARGET_FILE"; then
        # 使用 awk 在 return wasmConfig 前插入代码
        awk '
        /^[[:space:]]*return wasmConfig/ {
            print "\twasmConfig.FailOpen = plugin.FailStrategy == extensions.FailStrategy_FAIL_OPEN"
            print ""
        }
        { print }
        ' "$TARGET_FILE" > "${TARGET_FILE}.tmp" && mv "${TARGET_FILE}.tmp" "$TARGET_FILE"

        echo "Successfully patched $TARGET_FILE."

        # 打印打补丁后的文件内容
        echo "==================== [File Content: $TARGET_FILE] ===================="
        cat "$TARGET_FILE"
        echo "======================================================================"
    else
        echo "Patch already exists in $TARGET_FILE, skipping."
    fi
else
    echo "Warning: $TARGET_FILE not found!"
fi

# Update root go.mod after all external dependencies are ready
go mod tidy
