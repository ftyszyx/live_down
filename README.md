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


# 需求
一个桌面程序
## 功能：
用户输入直播平台分享的链接
程序可以通过链接解析出直播视频的真正下载地址
并下载视频到本地
需要支持多个平台：淘宝、抖音、快手、微信、youtube
以淘宝为例：
用户分享的地址内容如下
```
88《FVTtVunuUGt?? https://m.tb.cn/h.h27lk2I  CZ321 电器严选直发的直播简直太火爆了，快来看！
```
其它https://m.tb.cn/h.h27lk2I为直播视频短链，打开这个短链接，会自动跳转
```
https://diantao.cn/live-room-share/web/home.html?ut_sk=1.Z4ocC1FkIfoDAL7HS2EClXvj_25332598_1750323541417.Copy.dt_zhibo_corner&wh_cid=a2ca633b-cd4d-40c1-a2af-4404dccb4884&suid=9F4535BA-FA82-413C-8180-E701E2809BA4&id=523417747786&livetype=replay&livesource=share&cp_origin=taobaozhibo%7Ca2141.8001249%7C%7B%22feed_id%22%3A%22523417747786%22%2C%22account_id%22%3A%220%22%2C%22spm-cnt%22%3A%22a2141.8001249%22%2C%22app_key%22%3A%2225332598%22%2C%22os%22%3A%22ios%22%7D&type=508&sourceType=other&un=43211553c8951abfade3a8129ff9a52d&share_crt_v=1&un_site=0&spm=a2159r.13376460.0.0&sp_tk=RlZUdFZ1bnVVR3Q%3D&cpp=1&shareurl=true&short_name=h.h27lk2I&bxsign=scdVNR980WhBIC-e9YUbPHDwm8s6YYBCkPB1kJf5WdqNipCxlh2VpVC2laglvAS8fSv2Kvlj6N5zQCfWzZOwp9rozsPN3EpUyM4ZHpK61Iu-Epe3GWMgZDXflaxUnKJfbiK&app=chrome
```
将此跳转地址urldecode后
```
https://diantao.cn/live-room-share/web/home.html?ut_sk=1.Z4ocC1FkIfoDAL7HS2EClXvj_25332598_1750323541417.Copy.dt_zhibo_corner&wh_cid=a2ca633b-cd4d-40c1-a2af-4404dccb4884&suid=9F4535BA-FA82-413C-8180-E701E2809BA4&id=523417747786&livetype=replay&livesource=share&cp_origin=taobaozhibo|a2141.8001249|{"feed_id":"523417747786","account_id":"0","spm-cnt":"a2141.8001249","app_key":"25332598","os":"ios"}&type=508&sourceType=other&un=43211553c8951abfade3a8129ff9a52d&share_crt_v=1&un_site=0&spm=a2159r.13376460.0.0&sp_tk=RlZUdFZ1bnVVR3Q=&cpp=1&shareurl=true&short_name=h.h27lk2I&bxsign=scdVNR980WhBIC-e9YUbPHDwm8s6YYBCkPB1kJf5WdqNipCxlh2VpVC2laglvAS8fSv2Kvlj6N5zQCfWzZOwp9rozsPN3EpUyM4ZHpK61Iu-Epe3GWMgZDXflaxUnKJfbiK&app=chrome
```
其中的feed_id就是直播id
请求https://alive-interact.alicdn.com/livedetail/common/523417747786
可以获取直播的详情
```
{"accountId":2215846556688,"artpUrl":"artp://liveng-artp.alicdn.com/mediaplatform/a2ca633b-cd4d-40c1-a2af-4404dccb4884?auth_key=1752796838-0-0-3f949f6d23889ebd433b2849f4cb4e4e","bfrtcUrl":"artc://liveng-bfrtc.alibabausercontent.com/mediaplatform/a2ca633b-cd4d-40c1-a2af-4404dccb4884?auth_key=1752796838-0-0-fa9886b3194af041b32cd432bf7b6a9e","bizCode":"TAOBAO","broadCaster":{"accountId":2215846556688,"accountName":"电器严选直发","headImg":"https://img.alicdn.com/sns_logo/i2/2215846556688/O1CN01nqpgrC1zH9wM2L8i2_!!2215846556688-2-userheaderimgshow.png"},"coverImg":"https://gw.alicdn.com/tfscom/i2/O1CN01EbovjN1zH9wN1F7nv_!!4611686018427384848-0-dgshop.jpg","defaultImageUrl":"https://gw.alicdn.com/tfs/TB10l6bbz39YK4jSZPcXXXrUFXa-324-96.png","descInfo":"","displayDuration":10,"landScape":false,"liveConfigForStream":"{\"streamLevelPriorityList\":[\"0\",\"1\",\"2\",\"3\"],\"channelType\":\"live\",\"channelSubType\":\"hd_live\",\"ntpStartLiveOffset\":\"3959193638821\",\"dataChannelMsId\":\"rts data\",\"fpsNum\":\"25\",\"streamLevelInfo\":{},\"userLevel\":\"2\",\"pushControlStrategy\":\"base_transcode_1080_to_720\",\"trans1080P\":false,\"encoderImplType\":\"12\",\"experimentNamespace\":\"null\",\"landScape\":false,\"width\":\"1080\",\"channelId\":\"185fce86a79aef3c4749102cabbe7855\",\"height\":\"1920\"}","liveId":523417747786,"liveUrl":"http://liveng.alicdn.com/mediaplatform/a2ca633b-cd4d-40c1-a2af-4404dccb4884.flv?auth_key=1753456595-0-0-0c08584f7df900991788f0f48f5f11fe&source=null_null_TBLive_detailCDN&fromPlayControl=true","liveUrlHls":"http://liveng.alicdn.com/mediaplatform/a2ca633b-cd4d-40c1-a2af-4404dccb4884.m3u8?auth_key=1753456595-0-0-e3b72584311bcc3e8429150b8fa07722&source=null_null_TBLive_detailCDN","liveUrlList":[{"codeLevel":1,"definition":"ld","flvUrl":"http://liveng.alicdn.com/mediaplatform/a2ca633b-cd4d-40c1-a2af-4404dccb4884.flv?auth_key=1753456595-0-0-0c08584f7df900991788f0f48f5f11fe&source=null_null_TBLive_detailCDN&fromPlayControl=true","hlsUrl":"http://liveng.alicdn.com/mediaplatform/a2ca633b-cd4d-40c1-a2af-4404dccb4884.m3u8?auth_key=1753456595-0-0-e3b72584311bcc3e8429150b8fa07722&source=null_null_TBLive_detailCDN","name":"流畅","recomm":false},{"codeLevel":2,"definition":"md","flvUrl":"http://liveng.alicdn.com/mediaplatform/a2ca633b-cd4d-40c1-a2af-4404dccb4884.flv?auth_key=1753456595-0-0-0c08584f7df900991788f0f48f5f11fe&source=null_null_TBLive_detailCDN&fromPlayControl=true","hlsUrl":"http://liveng.alicdn.com/mediaplatform/a2ca633b-cd4d-40c1-a2af-4404dccb4884.m3u8?auth_key=1753456595-0-0-e3b72584311bcc3e8429150b8fa07722&source=null_null_TBLive_detailCDN","name":"高清","recomm":false},{"definition":"","flvUrl":"http://liveng.alicdn.com/mediaplatform/a2ca633b-cd4d-40c1-a2af-4404dccb4884.flv?auth_key=1753456595-0-0-0c08584f7df900991788f0f48f5f11fe&source=null_null_TBLive_detailCDN&fromPlayControl=true","hlsUrl":"http://liveng.alicdn.com/mediaplatform/a2ca633b-cd4d-40c1-a2af-4404dccb4884.m3u8?auth_key=1753456595-0-0-e3b72584311bcc3e8429150b8fa07722&source=null_null_TBLive_detailCDN","liveStreamStatsInfo":{"network":{"vatsb":{"avg":"3217067","min":"2360905","max":"4186060"}}},"newDefinition":"ud","newName":"蓝光","recomm":true}],"pushFeature":"Win_7.12.1_rtp_1080p_ElectronWin","replayUrl":"http://livenging.alicdn.com/mediaplatform/a2ca633b-cd4d-40c1-a2af-4404dccb4884_merge.m3u8","roomStatus":2,"streamStatus":0,"title":"电器严选618狂欢购","topic":"a2ca633b-cd4d-40c1-a2af-4404dccb4884","viewCount":155236}
```
其中的replayUrl就是m3u8地址，可以通过请求m3u8的信息，将视频下载到本地，并用ffmpeg合并成一个mp4文件
