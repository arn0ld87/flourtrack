create extension if not exists pgcrypto;

do $$
begin
  create type account_provider as enum ('guest', 'apple');
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create type factor_source as enum ('default', 'profile_arbitrary', 'random');
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create type friendship_status as enum ('pending', 'accepted', 'declined', 'blocked');
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create type game_rating as enum ('perfect', 'excellent', 'good', 'okay', 'too_slow');
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create type challenge_kind as enum ('reaction_under_ms', 'score_total', 'combo_length');
exception
  when duplicate_object then null;
end $$;

create table if not exists users (
  id uuid primary key default gen_random_uuid(),
  public_user_id text not null unique,
  account_provider account_provider not null default 'guest',
  apple_subject_hash text unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  last_seen_at timestamptz,
  deleted_at timestamptz,
  constraint users_public_user_id_format check (public_user_id ~ '^ft_[a-zA-Z0-9]{12,40}$'),
  constraint users_apple_subject_required check (
    account_provider <> 'apple' or apple_subject_hash is not null
  )
);

create table if not exists profiles (
  user_id uuid primary key references users(id) on delete cascade,
  display_name text,
  avatar_url text,
  height_cm numeric(5,2),
  weight_kg numeric(5,2),
  flour_track_factor numeric(3,2) not null default 1.00,
  factor_source factor_source not null default 'default',
  origin_city_name text not null default 'Leipzig',
  origin_latitude numeric(9,6) not null default 51.339695,
  origin_longitude numeric(9,6) not null default 12.373075,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profiles_display_name_length check (display_name is null or length(display_name) between 2 and 32),
  constraint profiles_height_range check (height_cm is null or height_cm between 90 and 250),
  constraint profiles_weight_range check (weight_kg is null or weight_kg between 25 and 350),
  constraint profiles_factor_range check (flour_track_factor between 0.80 and 1.20),
  constraint profiles_latitude_range check (origin_latitude between -90 and 90),
  constraint profiles_longitude_range check (origin_longitude between -180 and 180)
);

create table if not exists games (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users(id) on delete cascade,
  client_game_id uuid not null,
  reaction_time_ms integer not null,
  rating game_rating not null,
  accuracy_score integer not null,
  combo_multiplier numeric(5,2) not null,
  total_score integer not null,
  virtual_line_count numeric(10,3) not null default 1.000,
  virtual_distance_meters numeric(12,3) not null,
  played_at timestamptz not null,
  created_at timestamptz not null default now(),
  synced_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  constraint games_client_unique unique (user_id, client_game_id),
  constraint games_reaction_non_negative check (reaction_time_ms >= 0),
  constraint games_accuracy_range check (accuracy_score between 0 and 1000),
  constraint games_multiplier_positive check (combo_multiplier >= 1.00),
  constraint games_score_non_negative check (total_score >= 0),
  constraint games_virtual_line_positive check (virtual_line_count > 0),
  constraint games_virtual_distance_non_negative check (virtual_distance_meters >= 0)
);

create table if not exists friendships (
  id uuid primary key default gen_random_uuid(),
  requester_user_id uuid not null references users(id) on delete cascade,
  addressee_user_id uuid not null references users(id) on delete cascade,
  status friendship_status not null default 'pending',
  requested_at timestamptz not null default now(),
  responded_at timestamptz,
  updated_at timestamptz not null default now(),
  constraint friendships_no_self check (requester_user_id <> addressee_user_id),
  constraint friendships_pair_unique unique (requester_user_id, addressee_user_id)
);

create table if not exists achievements (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  localized_title_key text not null,
  localized_description_key text not null,
  rule jsonb not null,
  points integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint achievements_code_format check (code ~ '^[a-z0-9_]+$'),
  constraint achievements_points_non_negative check (points >= 0)
);

create table if not exists user_achievements (
  user_id uuid not null references users(id) on delete cascade,
  achievement_id uuid not null references achievements(id) on delete cascade,
  unlocked_at timestamptz not null default now(),
  source_game_id uuid references games(id) on delete set null,
  primary key (user_id, achievement_id)
);

create table if not exists daily_challenges (
  id uuid primary key default gen_random_uuid(),
  challenge_date date not null unique,
  kind challenge_kind not null,
  target_value integer not null,
  reward_points integer not null default 0,
  localized_title_key text not null,
  localized_description_key text not null,
  seed text not null,
  created_at timestamptz not null default now(),
  constraint daily_challenges_target_positive check (target_value > 0),
  constraint daily_challenges_reward_non_negative check (reward_points >= 0)
);

create table if not exists user_challenges (
  user_id uuid not null references users(id) on delete cascade,
  challenge_id uuid not null references daily_challenges(id) on delete cascade,
  progress_value integer not null default 0,
  completed_at timestamptz,
  updated_at timestamptz not null default now(),
  primary key (user_id, challenge_id),
  constraint user_challenges_progress_non_negative check (progress_value >= 0)
);

create table if not exists yearly_statistics (
  user_id uuid not null references users(id) on delete cascade,
  year integer not null,
  games_played integer not null default 0,
  total_score bigint not null default 0,
  best_score integer,
  best_reaction_time_ms integer,
  current_combo integer not null default 0,
  longest_combo integer not null default 0,
  daily_streak integer not null default 0,
  virtual_line_count numeric(12,3) not null default 0,
  virtual_distance_meters numeric(14,3) not null default 0,
  best_month smallint,
  best_weekday smallint,
  ranking_delta integer,
  recalculated_at timestamptz not null default now(),
  primary key (user_id, year),
  constraint yearly_statistics_year_range check (year between 2024 and 2100),
  constraint yearly_statistics_games_non_negative check (games_played >= 0),
  constraint yearly_statistics_score_non_negative check (total_score >= 0),
  constraint yearly_statistics_combo_non_negative check (current_combo >= 0 and longest_combo >= 0),
  constraint yearly_statistics_distance_non_negative check (virtual_line_count >= 0 and virtual_distance_meters >= 0),
  constraint yearly_statistics_best_month_range check (best_month is null or best_month between 1 and 12),
  constraint yearly_statistics_best_weekday_range check (best_weekday is null or best_weekday between 1 and 7)
);

create index if not exists users_account_provider_idx on users(account_provider);
create index if not exists users_created_at_idx on users(created_at);

create index if not exists games_user_played_at_idx on games(user_id, played_at desc);
create index if not exists games_played_at_idx on games(played_at desc);
create index if not exists games_total_score_idx on games(total_score desc);
create index if not exists games_metadata_gin_idx on games using gin(metadata);

create index if not exists friendships_addressee_status_idx on friendships(addressee_user_id, status);
create index if not exists friendships_requester_status_idx on friendships(requester_user_id, status);

create index if not exists achievements_active_idx on achievements(is_active) where is_active = true;
create index if not exists user_achievements_unlocked_at_idx on user_achievements(unlocked_at desc);

create index if not exists daily_challenges_date_idx on daily_challenges(challenge_date desc);
create index if not exists yearly_statistics_distance_idx on yearly_statistics(year, virtual_distance_meters desc);
create index if not exists yearly_statistics_score_idx on yearly_statistics(year, total_score desc);

insert into achievements (code, localized_title_key, localized_description_key, rule, points)
values
  ('rookie_baker', 'achievement.rookie_baker.title', 'achievement.rookie_baker.description', '{"type":"games_played","threshold":1}', 10),
  ('millisecond_master', 'achievement.millisecond_master.title', 'achievement.millisecond_master.description', '{"type":"reaction_under_ms","threshold":50}', 25),
  ('flour_power', 'achievement.flour_power.title', 'achievement.flour_power.description', '{"type":"games_played","threshold":100}', 50),
  ('precision_machine', 'achievement.precision_machine.title', 'achievement.precision_machine.description', '{"type":"perfect_combo","threshold":10}', 100),
  ('around_the_world', 'achievement.around_the_world.title', 'achievement.around_the_world.description', '{"type":"yearly_distance_km","threshold":40075}', 250),
  ('early_bird', 'achievement.early_bird.title', 'achievement.early_bird.description', '{"type":"local_play_hour_range","startHour":5,"endHour":7}', 25)
on conflict (code) do nothing;
