-- 注册用户的: 邮箱，手机，注册时间， 激活时间，
-- 注册用户的最后一次活动时间（搜索该用户下项目， 文件，问题，留言， 评论的创建时间， 如果都没有则以激活时间为准，没有激活的以注册时间为准）
-- 每个用户创建项目数量，参与的项目数量
-- 每个用户上传文件数量

select u.id, u.name, u.email, if(u.phone != '', u.phone, '') phone, u.register_date, 
if(u.active_date is null, '', u.active_date) active_date, 
if(a.last_activity_date is null,
    if(u.active_date is null,
        if(c.last_project_create_date is null, u.register_date, c.last_project_create_date),
        if(unix_timestamp(c.last_project_create_date) > unix_timestamp(u.active_date), c.last_project_create_date, u.active_date)), a.last_activity_date) last_active_date, 
b.create_project_num, b.participate_project_num, upload_file_num
from dx_user u
left join
(SELECT 
        dx_project_member.owner_id, SUBSTRING_INDEX(GROUP_CONCAT(b.last_date order by b.last_date desc), ',', 1) last_activity_date
    FROM
        dx_project_member
    LEFT JOIN (
		SELECT a.member_id, SUBSTRING_INDEX(GROUP_CONCAT(a.last_date ORDER BY a.last_date DESC), ',', 1) last_date
		FROM
			((SELECT uploader_id member_id,
					 STR_TO_DATE(SUBSTRING_INDEX(GROUP_CONCAT(date ORDER BY date DESC), ',', 1), '%Y-%m-%d %H:%i:%s') last_date
				FROM dx_content_file GROUP BY uploader_id) 
				UNION 
				(SELECT uploader_id member_id, 
							  STR_TO_DATE(SUBSTRING_INDEX(GROUP_CONCAT(date ORDER BY date DESC), ',', 1), '%Y-%m-%d %H:%i:%s') last_date
				 FROM
					dx_attachment
				 GROUP BY uploader_id) 
				 UNION 
				 (SELECT creator_id member_id,
						STR_TO_DATE(SUBSTRING_INDEX(GROUP_CONCAT(date ORDER BY date DESC), ',', 1), '%Y-%m-%d %H:%i:%s') last_date
					FROM
						dx_message
					GROUP BY creator_id) 
				 UNION 
				 (SELECT creator_id member_id,
					STR_TO_DATE(SUBSTRING_INDEX(GROUP_CONCAT(date ORDER BY date DESC), ',', 1), '%Y-%m-%d %H:%i:%s') last_date
					FROM
						dx_comment
			GROUP BY creator_id)) a
		GROUP BY a.member_id) b 
	ON b.member_id = dx_project_member.id
    group by dx_project_member.owner_id) a
on a.owner_id = u.id
left join 
(select p.owner_id, SUBSTRING_INDEX(GROUP_CONCAT(p.create_date ORDER BY p.create_date DESC), ',', 1) last_project_create_date 
	from dx_project p
	group by p.owner_id) c
on c.owner_id = u.id
left join
(SELECT 
    dx_user.id,
    dx_user.name,
    COALESCE(a.create_num, 0) create_project_num,
    COALESCE(b.participate_num, 0) participate_project_num,
    COALESCE(c.upload_file_num, 0) upload_file_num
FROM
    dx_user
        LEFT JOIN
    (SELECT 
        dx_project.owner_id, COUNT(dx_project.owner_id) create_num
    FROM
        dx_project
    GROUP BY dx_project.owner_id) a ON a.owner_id = dx_user.id
        LEFT JOIN
    (SELECT 
        dx_project_member.owner_id,
            COUNT(dx_project_member.owner_id) - 1 participate_num
    FROM
        dx_project_member
    GROUP BY dx_project_member.owner_id) b ON b.owner_id = dx_user.id
        LEFT JOIN
    (SELECT 
        dx_project_member.owner_id,
            COUNT(dx_project_member.owner_id) upload_file_num
    FROM
        dx_project_member
    INNER JOIN dx_content_file ON dx_content_file.uploader_id = dx_project_member.id
    GROUP BY dx_project_member.owner_id) c ON c.owner_id = dx_user.id) b
on u.id = b.id
order by u.register_date;
