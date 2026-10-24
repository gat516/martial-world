--!strict
-- Cultivator first names the creator offers a new character (docs/systems/character-creator.md):
-- the name field starts on one of these, and "New name" draws another, so a phone
-- player never has to type. Each must pass Rules.checkFirstName (2-14 letters);
-- the server still runs Roblox's text filter on whatever is sent.

local GivenNames: { string } = {
	"Yunfeng", "Lingxi", "Mochen", "Qingyu", "Feiyan", "Zhiruo", "Haoran", "Jingyi",
	"Ruoxi", "Tianming", "Xiaolan", "Wuji", "Shaoyang", "Yiran", "Mingyue", "Changkong",
	"Ziyan", "Lanruo", "Chenxi", "Xuanyi", "Baiye", "Qianmo", "Linfeng", "Yuheng",
	"Suyin", "Jinghong", "Weilan", "Fengxue", "Hanyu", "Shuangxi", "Yanqing", "Muyun",
	"Jianxin", "Qiuyue", "Lingfeng", "Xingchen", "Ruoshui", "Zhaoyun", "Wanqing", "Yuzhu",
	"Tianyu", "Liyan", "Qingshan", "Xueyi", "Mingzhe", "Huaxin", "Songhe", "Yaoguang",
	"Lianhua", "Jiuge", "Chuyun", "Xiaofeng", "Ningxue", "Shenyi", "Yunxi", "Zixuan",
}

return GivenNames
