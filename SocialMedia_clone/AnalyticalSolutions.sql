use ig_clone;

/* Find the 5 oldest users. */
select * from users order by created_at limit 5 ;
---------------------------------------------------------------------------------------------------------------------

/* We need to figure out when to schedule an ad campaign. Which day of the week do most users register on? */

with TempCTE as(
	select dayname(created_at), Count(created_at) as Count from users
	group by dayname(created_at)
	order by 2 desc
) select * from TempCTE where Count = (select Max(Count) from TempCTE);
---------------------------------------------------------------------------------------------------------------------

/* We want to target our inactive users with an email campaign. Find the users who have never posted a photo. */

select u.username, p.image_Url from users u
left outer join photos p
on u.id = p.user_id
where p.user_id is null;
---------------------------------------------------------------------------------------------------------------------

/* Which user has the single most liked photo? */

with tblLikes_Count as (
Select u.id, u.username as UserName, p.user_id ,l.photo_id, Count(*) as likescount from likes l
inner join photos p on l.photo_id = p.id
inner join users u on u.id = p.user_id
group by l.photo_id order by likescount desc
)
select id, UserName, likescount from tblLikes_Count where likescount = (select Max(likescount) from tblLikes_Count);
---------------------------------------------------------------------------------------------------------------------

/* How many times does the average user post? */

select ((select Count(*) from photos) / (select Count(*) from users)) as Average_posts_per_User;
---------------------------------------------------------------------------------------------------------------------

/* What are the top 5 most used hashtags? */

with tbltagcounts as (
	select t.id, t.tag_name, count(pt.photo_id) as taggedcount
	from photo_tags pt
	inner join tags t
	on t.id = pt.tag_id
	group by tag_id
)
select id, group_concat(tag_name) as Tag_names, taggedcount
from tbltagcounts
group by taggedcount
order by taggedcount desc
limit 5;
---------------------------------------------------------------------------------------------------------------------

/* We want to identify users who may be bots. Find the users who have liked every post? */

with Count_of_userlikes as(
	select u.username, l.user_id, count(*) as likescount from likes l
	join users u
	on u.Id = l.User_id
	group by l.user_id
)
select username, user_id, likescount from Count_of_userlikes
where likescount = (select count(*) from photos);
---------------------------------------------------------------------------------------------------------------------

/* Find users who have never commented on a photo */

select users.username, comments.comment_text from users
left outer join comments
on users.ID = comments.user_id
where comments.comment_text is null;
---------------------------------------------------------------------------------------------------------------------

/* what is the number of followers per users */

select u.username, f.followee_id, count(f.follower_id) as followers_Count from `follows` f
left outer join users u
on u.id = f.followee_id
group by f.followee_id
order by 3 desc;
---------------------------------------------------------------------------------------------------------------------

/* What is the engagement rate per follower ?  (likes+comments/total followers * 100) */

	select follower_id, total_comments, total_likes,
			(total_comments + total_likes) as engagement,
			(total_comments + total_likes)*100/(count(follower_id) over()) as engagement_rate
	from
			(select f.follower_id,
				count(distinct comment_text) as total_comments
				from `follows` f
				left outer join comments c on f.follower_id = c.user_id
				group by f.follower_id) as comments_count
			inner join
				(select user_id, count(*) as total_likes from likes group by user_id) as likes_count
			on follower_ID = likes_count.user_id
			group by follower_id;
---------------------------------------------------------------------------------------------------------------------

-- Find the minimum number of hashtags used by any user.

with tblfinal as(
		with ctename as ( 
				select p.id, p.user_id,
				count(pt.tag_id) as tagscount,
				group_concat(pt.tag_id) as group_of_tag_ids
				from photos p
                left outer join photo_tags pt
                on p.id = pt.photo_id
                group by p.id
                -- order by tagscount
		)
		Select u.id as user_ID, u.username, c.id as PhotoID, c.tagscount from CTEname c
		-- inner join photos p on p.id = c.Photo_id
		right outer join users u on u.id = c.user_id
		-- group by u.username
		order by 2 desc
		)
Select Distinct(username), 
(Max(tagscount) over(partition by username)) as Maximum_tags,
(Min(tagscount) over(partition by username)) as Minimunm_tags 
from tblfinal;
---------------------------------------------------------------------------------------------------------------------       
        
/* Find the photo with maximum comments. - Photo_id: 13,157,247
        a.    Does the photo have maximum likes also? - Nope
        b.    Find the photo with maximum likes - Photo_id: 145
        c.    who does this photo belong to? - Harley_lind18, Cesar93, Keenan.Schamberger60
        d.    Is the user popular ? - Cesar93 is popular with 77 followers.
        e.    Are the hashtags used are popular ones? - 
*/
with maintable as(
	with Photo_Comments as ( select u.id, u.username, p.image_url, 
					c.photo_id, count(c.comment_text) as commentscount
					from photos p
					left outer join comments c on p.id = c.photo_id
					inner join users u on p.user_id = u.id
					group by p.id),
		Photo_likes as 	( select photo_id as photid_tbllikes, count(user_id) as likescount from  likes
					group by photo_id),
		Photo_tags_tbl as 	( select photo_id as photoid_tblpt, group_concat(tag_id) as Tags_used_per_photo
					from photo_tags
					group by photo_id),
		followers_tbl as 	( select followee_id, count(follower_id) as followercount from `follows` 
					group by followee_id)
    select * from Photo_Comments
    left outer join Photo_likes on Photo_Comments.photo_id = Photo_likes.photid_tbllikes
    left outer join followers_tbl on Photo_Comments.id = followers_tbl.followee_id
    left outer join Photo_tags_tbl on Photo_Comments.photo_id = Photo_tags_tbl.photoid_tblpt
)
select
	id as user_id, username, photo_id,commentscount,likescount,tags_used_per_photo,followercount,
    	Case when tags_used_per_photo like 
		concat('%',(select tag_id as Populartag from photo_tags group by tag_id order by count(tag_id) desc limit 1),'%')
		then 'Used'
        else 'Not used'
        end as Most_Popolar_tag
    from maintable
	where ((commentscount = (select max(commentscount) from maintable)) or
			(likescount = (select max(likescount) from maintable)) and
            ( tags_used_per_photo like 
				concat('%',(select tag_id from photo_tags group by tag_id order by count(tag_id) desc limit 1),'%')
			))
			-- or (followercount = (select max(followercount) from maintable))
	order by 4 desc;
---------------------------------------------------------------------------------------------------------------------

/* Find the tags which attract maximum likes. */

with maintbl as(
		select pt.*, tbllikes.likescount from photo_tags pt
		left outer join
		(select photo_id, count(user_id) as likescount from likes group by photo_id order by likescount desc) as tblLikes
		on pt.photo_id = tbllikes.photo_id
)
select tag_id, count(tag_id) as usage_count 
from maintbl
where likescount between
	(select distinct(likescount) from maintbl order by likescount desc limit 1 offset 4) -- or use limit 4,1
    and
	(select distinct(likescount) from maintbl order by likescount desc limit 1)
group by tag_id order by usage_count desc;

---------------------------------------------------------------------------------------------------------------------

/* Find the percentage of active and inactive followers per user id. */

select distinct(follower_id) from follows;

with Maintbl as
(
	with tbluser_status as
	(
		select u.id, 
			case when p.user_id then 1 else 0 end as posted,
			case when l.user_id then 1 else 0 end as liked,
			case when c.user_id then 1 else 0 end as commented
		from users u
		left outer join photos p on u.id = p.user_id
		left outer join likes l on u.id = l.user_id
		left outer join comments c on u.id = c.user_id
		group by id
	)
	select f.followee_id, f.follower_id, -- us.id as user_id,
			case when (us.posted + us.liked + us.commented) = 0 then 0 else 1 end as follower_activity 
	from tbluser_status us
	left outer join `follows` f on f.follower_id = us.id
	order by followee_id
)
select followee_id,
		(sum(follower_activity)/count(follower_activity))*100 as Active_users_percentage,
       		 ((count(follower_activity) - sum(follower_activity))/count(follower_activity))*100 as inactive_users_percentage
from Maintbl
group by followee_id
;

---------------------------------------------------------------------------------------------------------------------

/* How many times a follower commented on a photo posted by user */

Select Photo_id, user_Id, count(user_id) -- over(partition by photo_id),
		-- row_number() over(partition by user_id)
 from comments
 group by Photo_id, user_id
 order by 1 asc, 3 Desc;
 
---------------------------------------------------------------------------------------------------------------------

/* Do all the followers like all the photos of followee? - are they bots or not? */
-- Private accounts (No. of followers = no. of likes per post, then Yes, otherwise No)
-- Public accounts (followers Ids and liked_user ids needs to be compared to conclude).

/* Assuming All user accounts are  Private accounts*/
select p.id, p.user_id as posted_User,
		l.photo_id, count(l.user_id) as follower_likes,
		f.followers,
        case when count(l.user_id) = followers then 1 else 0 end as All_followers_likes_followee_photo
from likes l
left outer join photos p on l.photo_id = p.id
left outer join 
		(select followee_id as User_id, count(follower_id) as followers from `follows` group by followee_id) as f
on p.user_id = f.user_id
group by p.id;

