-- =========================================================
-- FOUNDRY: MIGRATION 0010
-- DISCOVERY QUESTION BANK
-- Target: Development database (London)
-- =========================================================

begin;

insert into public.discovery_questions (
  key,
  version,
  prompt,
  help_text,
  answer_type,
  options,
  audience,
  category,
  position,
  is_active
)
values

-- ---------------------------------------------------------
-- SKILLS
-- ---------------------------------------------------------

(
  'primary_skills',
  1,
  'What are you particularly good at?',
  'Think about skills you have developed through work, education, hobbies or personal projects.',
  'multi_choice',
  '[
    {"value":"creative","label":"Creative and design"},
    {"value":"communication","label":"Communication and writing"},
    {"value":"sales","label":"Sales and persuasion"},
    {"value":"organisation","label":"Organisation and administration"},
    {"value":"technical","label":"Technology and technical skills"},
    {"value":"research","label":"Research and analysis"},
    {"value":"management","label":"Leadership and management"},
    {"value":"practical","label":"Practical and hands-on work"},
    {"value":"marketing","label":"Marketing and social media"},
    {"value":"problem_solving","label":"Problem solving"}
  ]'::jsonb,
  'adult',
  'skills',
  10,
  true
),

(
  'skill_strength',
  1,
  'Which of your skills would you feel most confident charging someone for?',
  'Select the skill you believe could create the most immediate value for another person or business.',
  'free_text',
  '[]'::jsonb,
  'adult',
  'skills',
  20,
  true
),

(
  'skill_development',
  1,
  'What would you most like to learn or become better at?',
  null,
  'free_text',
  '[]'::jsonb,
  'adult',
  'skills',
  30,
  true
),

-- ---------------------------------------------------------
-- EXPERIENCE
-- ---------------------------------------------------------

(
  'work_background',
  1,
  'What industries or types of work have you been involved in?',
  'Include employment, self-employment, volunteering and informal experience.',
  'multi_choice',
  '[
    {"value":"business","label":"Business and administration"},
    {"value":"transport","label":"Transport and logistics"},
    {"value":"retail","label":"Retail and customer service"},
    {"value":"hospitality","label":"Hospitality and food"},
    {"value":"construction","label":"Construction and trades"},
    {"value":"technology","label":"Technology"},
    {"value":"creative","label":"Creative industries"},
    {"value":"marketing","label":"Marketing and media"},
    {"value":"health","label":"Health and care"},
    {"value":"education","label":"Education"},
    {"value":"other","label":"Other"}
  ]'::jsonb,
  'adult',
  'experience',
  40,
  true
),

(
  'business_experience',
  1,
  'Have you previously started, owned or operated a business?',
  null,
  'single_choice',
  '[
    {"value":"yes_current","label":"Yes, I currently operate a business"},
    {"value":"yes_previous","label":"Yes, I have previously operated a business"},
    {"value":"informal","label":"I have run informal side projects"},
    {"value":"no","label":"No, this would be my first"}
  ]'::jsonb,
  'adult',
  'experience',
  50,
  true
),

(
  'notable_experience',
  1,
  'What experience do you have that you think could be commercially valuable?',
  'This might include industry knowledge, professional relationships, specialist knowledge or unusual experience.',
  'free_text',
  '[]'::jsonb,
  'adult',
  'experience',
  60,
  true
),

-- ---------------------------------------------------------
-- INTERESTS
-- ---------------------------------------------------------

(
  'business_interests',
  1,
  'Which areas genuinely interest you?',
  'Consider industries, activities and subjects you naturally enjoy learning about.',
  'multi_choice',
  '[
    {"value":"technology","label":"Technology and AI"},
    {"value":"fashion","label":"Fashion and beauty"},
    {"value":"design","label":"Design and branding"},
    {"value":"property","label":"Property and real estate"},
    {"value":"finance","label":"Finance and investing"},
    {"value":"health","label":"Health and wellness"},
    {"value":"education","label":"Education and learning"},
    {"value":"ecommerce","label":"E-commerce and retail"},
    {"value":"logistics","label":"Transport and logistics"},
    {"value":"media","label":"Media and entertainment"},
    {"value":"hospitality","label":"Hospitality and travel"},
    {"value":"environment","label":"Environment and sustainability"}
  ]'::jsonb,
  'adult',
  'interests',
  70,
  true
),

(
  'preferred_work',
  1,
  'What type of work would you most enjoy doing?',
  null,
  'multi_choice',
  '[
    {"value":"creating","label":"Creating products or designs"},
    {"value":"researching","label":"Researching and analysing"},
    {"value":"selling","label":"Selling and negotiating"},
    {"value":"building","label":"Building systems and technology"},
    {"value":"managing","label":"Managing operations"},
    {"value":"teaching","label":"Teaching and helping others"},
    {"value":"marketing","label":"Marketing and creating content"},
    {"value":"automating","label":"Automating processes"}
  ]'::jsonb,
  'adult',
  'interests',
  80,
  true
),

-- ---------------------------------------------------------
-- RESOURCES
-- ---------------------------------------------------------

(
  'starting_budget',
  1,
  'How much money could you realistically invest in starting a business?',
  'Consider money you could afford to risk without compromising essential expenses.',
  'single_choice',
  '[
    {"value":"zero","label":"Nothing at the moment"},
    {"value":"under_500","label":"Under $500"},
    {"value":"500_2000","label":"$500–$2,000"},
    {"value":"2000_5000","label":"$2,000–$5,000"},
    {"value":"5000_10000","label":"$5,000–$10,000"},
    {"value":"over_10000","label":"More than $10,000"}
  ]'::jsonb,
  'adult',
  'resources',
  90,
  true
),

(
  'available_time',
  1,
  'How much time could you realistically dedicate to a business each week?',
  null,
  'single_choice',
  '[
    {"value":"under_5","label":"Under 5 hours"},
    {"value":"5_10","label":"5–10 hours"},
    {"value":"10_20","label":"10–20 hours"},
    {"value":"20_30","label":"20–30 hours"},
    {"value":"30_plus","label":"More than 30 hours"}
  ]'::jsonb,
  'adult',
  'resources',
  100,
  true
),

(
  'existing_assets',
  1,
  'What resources or advantages do you already have access to?',
  'Examples include equipment, software, workspace, an audience, industry contacts or an existing business.',
  'free_text',
  '[]'::jsonb,
  'adult',
  'resources',
  110,
  true
),

-- ---------------------------------------------------------
-- CONSTRAINTS
-- ---------------------------------------------------------

(
  'business_constraints',
  1,
  'What would make starting a business difficult for you?',
  null,
  'multi_choice',
  '[
    {"value":"capital","label":"Limited starting capital"},
    {"value":"time","label":"Limited available time"},
    {"value":"experience","label":"Lack of experience"},
    {"value":"confidence","label":"Lack of confidence"},
    {"value":"technical","label":"Limited technical knowledge"},
    {"value":"network","label":"Limited professional network"},
    {"value":"regulation","label":"Industry regulations or licensing"},
    {"value":"uncertain","label":"I am not sure yet"}
  ]'::jsonb,
  'adult',
  'constraints',
  120,
  true
),

(
  'business_preferences',
  1,
  'Are there any types of businesses or work you would prefer to avoid?',
  'For example, businesses requiring employees, physical premises, inventory or extensive customer interaction.',
  'free_text',
  '[]'::jsonb,
  'adult',
  'constraints',
  130,
  true
),

-- ---------------------------------------------------------
-- GOALS
-- ---------------------------------------------------------

(
  'primary_goal',
  1,
  'What is your main reason for wanting to start a business?',
  null,
  'single_choice',
  '[
    {"value":"income","label":"Create an additional income stream"},
    {"value":"replace_income","label":"Replace my employment income"},
    {"value":"wealth","label":"Build long-term wealth"},
    {"value":"freedom","label":"Gain financial and lifestyle freedom"},
    {"value":"passion","label":"Turn an interest into a business"},
    {"value":"scale","label":"Build a large, scalable company"},
    {"value":"independence","label":"Become self-employed"}
  ]'::jsonb,
  'adult',
  'goals',
  140,
  true
),

(
  'income_target',
  1,
  'What monthly business income would you ultimately like to achieve?',
  'Enter your approximate target before tax.',
  'single_choice',
  '[
    {"value":"under_1000","label":"Under $1,000"},
    {"value":"1000_5000","label":"$1,000–$5,000"},
    {"value":"5000_10000","label":"$5,000–$10,000"},
    {"value":"10000_25000","label":"$10,000–$25,000"},
    {"value":"25000_50000","label":"$25,000–$50,000"},
    {"value":"over_50000","label":"More than $50,000"}
  ]'::jsonb,
  'adult',
  'goals',
  150,
  true
),

(
  'growth_ambition',
  1,
  'How would you like your business to grow?',
  null,
  'single_choice',
  '[
    {"value":"solo","label":"Remain a solo operator"},
    {"value":"small_team","label":"Build a small team"},
    {"value":"automated","label":"Build an automated business"},
    {"value":"agency","label":"Build an agency or service company"},
    {"value":"product","label":"Build a scalable product or platform"},
    {"value":"large_company","label":"Build a large company"}
  ]'::jsonb,
  'adult',
  'goals',
  160,
  true
),

-- ---------------------------------------------------------
-- VALUES
-- ---------------------------------------------------------

(
  'business_values',
  1,
  'What matters most to you when building a business?',
  null,
  'multi_choice',
  '[
    {"value":"independence","label":"Independence"},
    {"value":"creativity","label":"Creativity"},
    {"value":"profitability","label":"Profitability"},
    {"value":"flexibility","label":"Flexibility"},
    {"value":"impact","label":"Positive impact"},
    {"value":"innovation","label":"Innovation"},
    {"value":"stability","label":"Stability"},
    {"value":"growth","label":"Growth and ambition"}
  ]'::jsonb,
  'adult',
  'values',
  170,
  true
),

(
  'risk_tolerance',
  1,
  'How comfortable are you with taking calculated business risks?',
  null,
  'single_choice',
  '[
    {"value":"low","label":"I prefer low-risk opportunities"},
    {"value":"moderate","label":"I am comfortable with moderate risk"},
    {"value":"high","label":"I am comfortable taking significant risks"}
  ]'::jsonb,
  'adult',
  'values',
  180,
  true
),

(
  'business_definition',
  1,
  'What would make a business feel successful to you beyond money?',
  'Think about the lifestyle, impact or achievements you want your business to create.',
  'free_text',
  '[]'::jsonb,
  'adult',
  'values',
  190,
  true
)

on conflict (key, version) do update
set
  prompt = excluded.prompt,
  help_text = excluded.help_text,
  answer_type = excluded.answer_type,
  options = excluded.options,
  audience = excluded.audience,
  category = excluded.category,
  position = excluded.position,
  is_active = excluded.is_active;

commit;
