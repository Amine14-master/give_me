mkdir releases -Force -ErrorAction SilentlyContinue
Copy-Item client\build\app\outputs\flutter-apk\app-release.apk releases\give_me-release.apk -Force
echo "# give_me" >> README.md
git init
git add .
git add -f releases\give_me-release.apk
git commit -m "first commit"
git branch -M main
git remote add origin https://github.com/Amine14-master/give_me.git
git push -u origin main
