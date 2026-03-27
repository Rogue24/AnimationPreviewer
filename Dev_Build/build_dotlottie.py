import os
import json
import zipfile
import shutil
import uuid
import argparse

def decompile_lottie(lottie_path):
    if not os.path.isfile(lottie_path) or not lottie_path.endswith(".lottie"):
        print("❌ 输入必须是 .lottie 文件")
        return

    base_name = os.path.splitext(os.path.basename(lottie_path))[0]
    output_dir = os.path.join(os.path.dirname(lottie_path), f"jp_{base_name}")

    temp_dir = f"temp_unzip_{uuid.uuid4().hex}"
    os.makedirs(temp_dir, exist_ok=True)

    # 解压
    with zipfile.ZipFile(lottie_path, "r") as z:
        z.extractall(temp_dir)

    manifest_path = os.path.join(temp_dir, "manifest.json")
    if not os.path.exists(manifest_path):
        print("❌ 缺少 manifest.json")
        shutil.rmtree(temp_dir)
        return

    with open(manifest_path, "r", encoding="utf-8") as f:
        manifest = json.load(f)

    version = str(manifest.get("version", "1"))

    # 判断目录名
    animations_folder_name = "a" if int(version) > 1 else "animations"
    images_folder_name = "i" if int(version) > 1 else "images"

    animations_dir = os.path.join(temp_dir, animations_folder_name)
    images_dir = os.path.join(temp_dir, images_folder_name)

    os.makedirs(output_dir, exist_ok=True)

    # 还原 json
    if os.path.exists(animations_dir):
        for file in os.listdir(animations_dir):
            if file.endswith(".json"):
                shutil.copy(
                    os.path.join(animations_dir, file),
                    os.path.join(output_dir, file)
                )

    # 还原 images（统一改回 images）
    if os.path.exists(images_dir):
        target_images_dir = os.path.join(output_dir, "images")
        shutil.copytree(images_dir, target_images_dir, dirs_exist_ok=True)

    shutil.rmtree(temp_dir)

    print(f"✅ 反编译成功: {output_dir}")


def create_lottie(input_dir, version="1"):
    if not os.path.isdir(input_dir):
        print("❌ 输入路径必须是文件夹")
        return

    json_files = [
        f for f in os.listdir(input_dir)
        if f.endswith(".json")
    ]

    if not json_files:
        print("❌ 该文件夹下必须包含 .json 文件")
        return

    folder_name = os.path.basename(os.path.abspath(input_dir))
    output_path = os.path.join(os.path.dirname(input_dir), f"jp_{folder_name}.lottie")

    temp_dir = f"temp_lottie_{uuid.uuid4().hex}"
    animations_folder_name = "a" if int(version) > 1 else "animations"
    animations_dir = os.path.join(temp_dir, animations_folder_name)
    os.makedirs(animations_dir, exist_ok=True)

    animations = []

    # 拷贝 json 到 animations，并构建 animations 配置
    for file_name in json_files:
        src_path = os.path.join(input_dir, file_name)
        dst_path = os.path.join(animations_dir, file_name)
        shutil.copy(src_path, dst_path)

        anim_id = os.path.splitext(file_name)[0]

        animations.append({
            "id": anim_id,
            "direction": 1,
            "speed": 1,
            "mode": "normal",
            "loop": True
        })

    # 生成 manifest.json（参考你提供的结构）
    manifest = {
        "version": str(version),
        "author": "zhoujianping",
        "generator": "build_dotlottie",
        "animations": animations
    }

    with open(os.path.join(temp_dir, "manifest.json"), "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=4, ensure_ascii=False)

    # 拷贝 images（如果存在）
    images_dir = os.path.join(input_dir, "images")
    if os.path.exists(images_dir):
        images_folder_name = "i" if int(version) > 1 else "images"
        shutil.copytree(images_dir, os.path.join(temp_dir, images_folder_name))

    # 打包为 .lottie
    with zipfile.ZipFile(output_path, "w", zipfile.ZIP_DEFLATED) as z:
        for root, _, files in os.walk(temp_dir):
            for file in files:
                full_path = os.path.join(root, file)
                rel_path = os.path.relpath(full_path, temp_dir)
                z.write(full_path, rel_path)

    shutil.rmtree(temp_dir)

    print(f"✅ 生成成功: {output_path}")


def main():
    parser = argparse.ArgumentParser(description="Build .lottie file")

    parser.add_argument(
        "input_dir",
        help="必须传入包含 .json 的文件夹路径"
    )
    parser.add_argument(
        "version",
        nargs="?",
        default="1",
        help="manifest version（必须为数字，默认1）"
    )

    args = parser.parse_args()

    input_path = os.path.abspath(args.input_dir)
    version = args.version

    if input_path.endswith(".lottie"):
        decompile_lottie(input_path)
        return

    if not version.isdigit():
        print("❌ version 必须是数字")
        return

    create_lottie(input_path, version)


if __name__ == "__main__":
    main()