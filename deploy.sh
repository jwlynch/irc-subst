deploy_dir="$HOME/.config/hexchat/addons"

rm -rf $deploy_dir/utils

cp -a utils $deploy_dir/

cp irc-subst.py $deploy_dir/

# uncomment the following for a small test script:
# cp test-word.py $deploy_dir/
