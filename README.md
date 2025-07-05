# live_down
livedown

# update package

flutter pub get -v

# run

flutter run -d windows

chrome ：https://commondatastorage.googleapis.com/chromium-browser-snapshots/index.html


# need
1. 日志记录
2. 下载器程序（用来下载aseet资源）
3. 设置页面，可以修改保存目录
4. 需要保存历史记录
5. 能断点续传


1.数据持久化，需要接入sqlite
  保存用户的设置
  保存上一次的下载任务列表ViewDownloadInfo 


2.asset目录下的内容会增加安装包大小
所以需要打包的程序将asset目录下的内容去掉，放在阿里云oss上。
程序在启动时需要从阿里云oss上下载最新的asset。然后启动。 

3、软件版本检查，
在程序启动时需要检查当前是否有版本更新，如果有，需要下载新的安装包，并重新安装

4. 使用innop setup制作windows 安装包
5. 

我做了一个软件，想为这个软件做一个付费系统
用户可以在这个系统上买注册码，在我的软件输入后，就会绑定软件安装的设备。
1、注册码需要有有效期
2、注册码需要有设备绑定限制
3、需要提供接口给客户端验证注册码是否有效
4、系统需要提供支付功能
有没有开源方案推荐


# code structure
core  共用的
feauters: 功能模块
ui :ui相关



下载进度用分片进度 分子是已经下载的分片  分母是总分片数
文件总大小使用预估大小
暂停下载后，如果用户打开文件目录就触发 文件合并同时清空临时文件



# 需求
一个桌面程序
## 功能：
用户输入直播平台分享的链接
程序可以通过链接解析出直播视频的真正下载地址
并下载视频到本地
需要支持多个平台：淘宝、抖音、快手、微信、youtube


//快手
从分享信息中获取短链

```
https://v.kuaishou.com/2ED6U1w 公牛家用蓝白款插排，多孔插线板，排插，插座转换器"公牛 "排插 "插排 "插线板 "公牛旗舰店
```
获取 
```
https://v.kuaishou.com/2ED6U1w
```
用chrome打开短链，等待最终的跳转地址：


获取页面内容，如果element中有 马上登录 

```
https://v.m.chenzhongtech.com/fw/photo/3x8uknwfv5kc952?cc=share_copylink&followRefer=151&shareMethod=TOKEN&docId=9&kpn=KUAISHOU&subBiz=BROWSE_SLIDE_PHOTO&photoId=3x8uknwfv5kc952&shareId=18462755111884&shareToken=X-aTzaFzAUc4d2iw&shareResourceType=PHOTO_OTHER&userId=3x9utskj8y839b6&shareType=1&et=1_u%2F2008493444016876993_sff0&shareMode=APP&efid=3xzpp9xevgsttag&originShareId=18462755111884&appType=21&shareObjectId=5246130770306096234&shareUrlOpened=0&timestamp=1751693927613
```

urldecode此地址
