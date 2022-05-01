deploy_dir="/home/jim/.config/hexchat/addons"

rm -rf $deploy_dir/utils

cp -a utils $deploy_dir/

cp irc-subst.py $deploy_dir/
