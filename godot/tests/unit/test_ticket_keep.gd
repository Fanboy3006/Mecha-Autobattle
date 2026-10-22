## 职责：招募券留存（作者 10-22 试玩反馈）：最多留 3 张；≤3 张且名册非空可以不招直接走；>3 张或名册空才拦。
extends RefCounted

func run(t) -> void:
	var errors := []
	t.ok(DataLoader.install(errors), "数据装入 Db%s" % ("" if errors.is_empty() else "：" + str(errors)))
	var s := GameSession.new()
	t.ok(s.start_new_run(20261016, "混编"), "开局")
	t.ok(RosterManager.券留存上限() == 3, "券留存上限 = 3（%d）" % RosterManager.券留存上限())
	t.ok(s.ticket_count() > 0 and s.roster_count() == 0 and s.有未决的招募券(), "名册空 + 有券：必须先招（券 %d）" % s.ticket_count())
	var 招到 := false
	for i in s.ticket_count():
		for 条 in s.available_recruit_targets(i):
			if 条 is Dictionary and bool(条.get("可招", true)):
				招到 = bool(s.recruit_unit(str(条.get("键", "")), i).get("ok", false))
				break
		if 招到:
			break
	t.ok(招到 and s.roster_count() == 1, "招到 1 台")
	var st := s.run_state
	st.pending_card_picks.clear()
	while s.ticket_count() < 3:
		RosterManager.发券(st, "职业", "测试")
	t.ok(s.ticket_count() == 3 and not s.有未决的招募券(), "名册非空 + 3 张券：可以留着不招")
	RosterManager.发券(st, "职业", "测试")
	t.ok(s.ticket_count() == 4 and s.有未决的招募券(), "4 张券：超过上限，必须先处理")
	t.ok(not s.fight_chase_battle(), "超上限时不许手动开追击战")
	t.ok(bool(s.discard_ticket(0).get("ok", false)) and not s.有未决的招募券(), "丢 1 张回到 3 张：放行")
	st.hope = 0
	t.ok(not s.有未决的招募券(), "希望 0 也不卡：券留着")
