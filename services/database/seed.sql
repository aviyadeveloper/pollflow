-- PollFlow Seed Data
-- Development and testing data for local environments
--
-- 20 news-related polls across categories with realistic vote distributions
-- Status breakdown: 5 pending, 10 active, 5 closed

-- =============================================================================
-- POLLS
-- =============================================================================

-- ACTIVE POLLS (10) - Started in past, ending in future
INSERT INTO polls (title, description, option_a, option_b, poll_category, start_time, end_time, status) VALUES
('Should AI companies be required to disclose training data sources?', 'New transparency bill debate in Congress', 'Yes, full disclosure', 'No, protect trade secrets', 'politics', NOW() - INTERVAL '6 hours', NOW() + INTERVAL '6 hours', 'active'),
('Is quantum computing ready for mainstream adoption?', 'Following IBM''s new 1000-qubit processor announcement', 'Yes, revolution incoming', 'No, still experimental', 'tech', NOW() - INTERVAL '3 hours', NOW() + INTERVAL '9 hours', 'active'),
('Will Team USA win the 2026 World Basketball Championship?', 'Tournament starts next month', 'Yes, they''re favorites', 'No, too much competition', 'sports', NOW() - INTERVAL '12 hours', NOW() + INTERVAL '12 hours', 'active'),
('Should the Mars colony project be publicly funded?', 'SpaceX requests $50B government partnership', 'Yes, human priority', 'No, private venture', 'science', NOW() - INTERVAL '8 hours', NOW() + INTERVAL '16 hours', 'active'),
('Is streaming quality declining despite price increases?', 'Netflix, Disney+ raise prices again', 'Yes, less content', 'No, still worth it', 'entertainment', NOW() - INTERVAL '2 hours', NOW() + INTERVAL '10 hours', 'active'),
('Should social media platforms be liable for misinformation?', 'Supreme Court hears landmark case', 'Yes, accountability needed', 'No, free speech risk', 'politics', NOW() - INTERVAL '5 hours', NOW() + INTERVAL '7 hours', 'active'),
('Will neural interface technology succeed commercially?', 'Neuralink announces human trial results', 'Yes, game changer', 'No, too invasive', 'tech', NOW() - INTERVAL '10 hours', NOW() + INTERVAL '14 hours', 'active'),
('Should professional esports be in the Olympics?', 'IOC opens discussions with gaming federations', 'Yes, it''s a sport', 'No, keep traditional', 'sports', NOW() - INTERVAL '4 hours', NOW() + INTERVAL '8 hours', 'active'),
('Is nuclear fusion finally viable for energy production?', 'Breakthrough: 10x energy gain achieved', 'Yes, energy revolution', 'No, decades away', 'science', NOW() - INTERVAL '7 hours', NOW() + INTERVAL '5 hours', 'active'),
('Should movie theaters survive in the streaming era?', 'AMC reports 40% revenue drop', 'Yes, unique experience', 'No, obsolete model', 'entertainment', NOW() - INTERVAL '1 hour', NOW() + INTERVAL '11 hours', 'active');

-- PENDING POLLS (5) - Starting in future
INSERT INTO polls (title, description, option_a, option_b, poll_category, start_time, end_time, status) VALUES
('Will the new climate bill pass before recess?', 'Senate vote scheduled for tomorrow', 'Yes, bipartisan support', 'No, too controversial', 'politics', NOW() + INTERVAL '2 hours', NOW() + INTERVAL '14 hours', 'pending'),
('Is 6G technology overhyped?', 'Carriers announce 6G roadmap despite 5G rollout', 'Yes, premature marketing', 'No, necessary innovation', 'tech', NOW() + INTERVAL '4 hours', NOW() + INTERVAL '16 hours', 'pending'),
('Should athlete salaries have caps across all sports?', 'Discussion after record $800M contract', 'Yes, more balance needed', 'No, market decides', 'sports', NOW() + INTERVAL '6 hours', NOW() + INTERVAL '18 hours', 'pending'),
('Will asteroid mining be profitable this decade?', 'First commercial mission launches next year', 'Yes, trillion dollar industry', 'No, too expensive', 'science', NOW() + INTERVAL '8 hours', NOW() + INTERVAL '20 hours', 'pending'),
('Should AI-generated content be labeled in entertainment?', 'Hollywood actors demand transparency rules', 'Yes, audiences deserve to know', 'No, stifles creativity', 'entertainment', NOW() + INTERVAL '10 hours', NOW() + INTERVAL '22 hours', 'pending');

-- CLOSED POLLS (5) - Both times in past
INSERT INTO polls (title, description, option_a, option_b, poll_category, start_time, end_time, status) VALUES
('Should cryptocurrency be accepted as legal tender?', 'El Salvador model debate', 'Yes, financial freedom', 'No, too volatile', 'politics', NOW() - INTERVAL '48 hours', NOW() - INTERVAL '24 hours', 'closed'),
('Was the metaverse worth the investment?', 'Meta reports $30B losses', 'Yes, long-term vision', 'No, failed experiment', 'tech', NOW() - INTERVAL '60 hours', NOW() - INTERVAL '36 hours', 'closed'),
('Should college athletes receive full salaries?', 'NCAA policy change proposal', 'Yes, they earn billions', 'No, scholarships enough', 'sports', NOW() - INTERVAL '72 hours', NOW() - INTERVAL '48 hours', 'closed'),
('Is lab-grown meat the future of food?', 'FDA approves expanded production', 'Yes, sustainable solution', 'No, real meat better', 'science', NOW() - INTERVAL '40 hours', NOW() - INTERVAL '16 hours', 'closed'),
('Should legacy sequels stop being made?', 'Another franchise reboot flops', 'Yes, need originality', 'No, nostalgia sells', 'entertainment', NOW() - INTERVAL '36 hours', NOW() - INTERVAL '12 hours', 'closed');

-- =============================================================================
-- VOTES
-- =============================================================================
-- Distribute votes across polls with varied patterns
-- Active and closed polls have votes, pending polls have none

-- Helper function to generate varied IP addresses
-- Using realistic IP patterns for diversity

-- Poll 1 votes (Active - AI transparency)
INSERT INTO votes (poll_id, user_ip, option, voted_at) VALUES
(1, '192.168.1.10', 'a', NOW() - INTERVAL '5 hours'),
(1, '192.168.1.11', 'a', NOW() - INTERVAL '5 hours'),
(1, '10.0.0.45', 'b', NOW() - INTERVAL '4 hours'),
(1, '172.16.0.23', 'a', NOW() - INTERVAL '4 hours'),
(1, '192.168.2.100', 'a', NOW() - INTERVAL '3 hours'),
(1, '10.1.1.50', 'b', NOW() - INTERVAL '3 hours'),
(1, '172.16.5.88', 'a', NOW() - INTERVAL '2 hours'),
(1, '192.168.3.77', 'a', NOW() - INTERVAL '2 hours'),
(1, '10.0.1.99', 'b', NOW() - INTERVAL '1 hour'),
(1, '172.16.8.15', 'a', NOW() - INTERVAL '1 hour');

-- Poll 2 votes (Active - Quantum computing)
INSERT INTO votes (poll_id, user_ip, option, voted_at) VALUES
(2, '192.168.10.5', 'b', NOW() - INTERVAL '2 hours'),
(2, '10.5.5.25', 'b', NOW() - INTERVAL '2 hours'),
(2, '172.20.0.33', 'a', NOW() - INTERVAL '2 hours'),
(2, '192.168.11.44', 'b', NOW() - INTERVAL '1 hour'),
(2, '10.6.7.89', 'b', NOW() - INTERVAL '1 hour'),
(2, '172.21.3.55', 'a', NOW() - INTERVAL '30 minutes'),
(2, '192.168.12.66', 'b', NOW() - INTERVAL '30 minutes');

-- Poll 3 votes (Active - Basketball championship)
INSERT INTO votes (poll_id, user_ip, option, voted_at) VALUES
(3, '192.168.20.1', 'a', NOW() - INTERVAL '11 hours'),
(3, '10.10.10.10', 'a', NOW() - INTERVAL '10 hours'),
(3, '172.30.1.20', 'a', NOW() - INTERVAL '9 hours'),
(3, '192.168.21.30', 'b', NOW() - INTERVAL '8 hours'),
(3, '10.11.12.40', 'a', NOW() - INTERVAL '7 hours'),
(3, '172.31.2.50', 'a', NOW() - INTERVAL '6 hours'),
(3, '192.168.22.60', 'a', NOW() - INTERVAL '5 hours'),
(3, '10.12.13.70', 'b', NOW() - INTERVAL '4 hours'),
(3, '172.32.3.80', 'a', NOW() - INTERVAL '3 hours'),
(3, '192.168.23.90', 'a', NOW() - INTERVAL '2 hours'),
(3, '10.13.14.100', 'a', NOW() - INTERVAL '1 hour');

-- Poll 4 votes (Active - Mars funding)
INSERT INTO votes (poll_id, user_ip, option, voted_at) VALUES
(4, '192.168.30.15', 'a', NOW() - INTERVAL '7 hours'),
(4, '10.20.20.25', 'b', NOW() - INTERVAL '6 hours'),
(4, '172.40.4.35', 'a', NOW() - INTERVAL '5 hours'),
(4, '192.168.31.45', 'a', NOW() - INTERVAL '4 hours'),
(4, '10.21.21.55', 'b', NOW() - INTERVAL '3 hours'),
(4, '172.41.5.65', 'a', NOW() - INTERVAL '2 hours');

-- Poll 5 votes (Active - Streaming quality)
INSERT INTO votes (poll_id, user_ip, option, voted_at) VALUES
(5, '192.168.40.5', 'a', NOW() - INTERVAL '1 hour'),
(5, '10.30.30.15', 'a', NOW() - INTERVAL '1 hour'),
(5, '172.50.6.25', 'b', NOW() - INTERVAL '1 hour'),
(5, '192.168.41.35', 'a', NOW() - INTERVAL '30 minutes'),
(5, '10.31.31.45', 'a', NOW() - INTERVAL '30 minutes'),
(5, '172.51.7.55', 'b', NOW() - INTERVAL '15 minutes'),
(5, '192.168.42.65', 'a', NOW() - INTERVAL '15 minutes'),
(5, '10.32.32.75', 'a', NOW() - INTERVAL '10 minutes');

-- Poll 6 votes (Active - Social media liability)
INSERT INTO votes (poll_id, user_ip, option, voted_at) VALUES
(6, '192.168.50.10', 'a', NOW() - INTERVAL '4 hours'),
(6, '10.40.40.20', 'a', NOW() - INTERVAL '3 hours'),
(6, '172.60.8.30', 'b', NOW() - INTERVAL '2 hours'),
(6, '192.168.51.40', 'a', NOW() - INTERVAL '1 hour');

-- Poll 7 votes (Active - Neural interfaces)
INSERT INTO votes (poll_id, user_ip, option, voted_at) VALUES
(7, '192.168.60.7', 'a', NOW() - INTERVAL '9 hours'),
(7, '10.50.50.17', 'b', NOW() - INTERVAL '8 hours'),
(7, '172.70.9.27', 'b', NOW() - INTERVAL '7 hours'),
(7, '192.168.61.37', 'a', NOW() - INTERVAL '6 hours'),
(7, '10.51.51.47', 'b', NOW() - INTERVAL '5 hours'),
(7, '172.71.10.57', 'b', NOW() - INTERVAL '4 hours'),
(7, '192.168.62.67', 'a', NOW() - INTERVAL '3 hours'),
(7, '10.52.52.77', 'b', NOW() - INTERVAL '2 hours'),
(7, '172.72.11.87', 'b', NOW() - INTERVAL '1 hour');

-- Poll 8 votes (Active - Esports in Olympics)
INSERT INTO votes (poll_id, user_ip, option, voted_at) VALUES
(8, '192.168.70.12', 'a', NOW() - INTERVAL '3 hours'),
(8, '10.60.60.22', 'a', NOW() - INTERVAL '2 hours'),
(8, '172.80.12.32', 'b', NOW() - INTERVAL '1 hour'),
(8, '192.168.71.42', 'a', NOW() - INTERVAL '30 minutes'),
(8, '10.61.61.52', 'a', NOW() - INTERVAL '15 minutes');

-- Poll 9 votes (Active - Nuclear fusion)
INSERT INTO votes (poll_id, user_ip, option, voted_at) VALUES
(9, '192.168.80.8', 'a', NOW() - INTERVAL '6 hours'),
(9, '10.70.70.18', 'a', NOW() - INTERVAL '5 hours'),
(9, '172.90.13.28', 'a', NOW() - INTERVAL '4 hours'),
(9, '192.168.81.38', 'b', NOW() - INTERVAL '3 hours'),
(9, '10.71.71.48', 'a', NOW() - INTERVAL '2 hours'),
(9, '172.91.14.58', 'a', NOW() - INTERVAL '1 hour'),
(9, '192.168.82.68', 'a', NOW() - INTERVAL '30 minutes');

-- Poll 10 votes (Active - Movie theaters)
INSERT INTO votes (poll_id, user_ip, option, voted_at) VALUES
(10, '192.168.90.3', 'a', NOW() - INTERVAL '45 minutes'),
(10, '10.80.80.13', 'b', NOW() - INTERVAL '30 minutes'),
(10, '172.100.15.23', 'a', NOW() - INTERVAL '20 minutes'),
(10, '192.168.91.33', 'a', NOW() - INTERVAL '10 minutes');

-- Poll 16 votes (Closed - Cryptocurrency)
INSERT INTO votes (poll_id, user_ip, option, voted_at) VALUES
(16, '192.168.100.20', 'b', NOW() - INTERVAL '47 hours'),
(16, '10.90.90.30', 'b', NOW() - INTERVAL '46 hours'),
(16, '172.110.16.40', 'a', NOW() - INTERVAL '45 hours'),
(16, '192.168.101.50', 'b', NOW() - INTERVAL '44 hours'),
(16, '10.91.91.60', 'b', NOW() - INTERVAL '43 hours'),
(16, '172.111.17.70', 'a', NOW() - INTERVAL '42 hours'),
(16, '192.168.102.80', 'b', NOW() - INTERVAL '41 hours'),
(16, '10.92.92.90', 'b', NOW() - INTERVAL '40 hours'),
(16, '172.112.18.100', 'a', NOW() - INTERVAL '39 hours'),
(16, '192.168.103.110', 'b', NOW() - INTERVAL '38 hours'),
(16, '10.93.93.120', 'b', NOW() - INTERVAL '37 hours'),
(16, '172.113.19.130', 'a', NOW() - INTERVAL '36 hours'),
(16, '192.168.104.140', 'b', NOW() - INTERVAL '35 hours'),
(16, '10.94.94.150', 'b', NOW() - INTERVAL '34 hours'),
(16, '172.114.20.160', 'b', NOW() - INTERVAL '33 hours');

-- Poll 17 votes (Closed - Metaverse investment)
INSERT INTO votes (poll_id, user_ip, option, voted_at) VALUES
(17, '192.168.110.25', 'b', NOW() - INTERVAL '59 hours'),
(17, '10.100.100.35', 'b', NOW() - INTERVAL '58 hours'),
(17, '172.120.21.45', 'a', NOW() - INTERVAL '57 hours'),
(17, '192.168.111.55', 'b', NOW() - INTERVAL '56 hours'),
(17, '10.101.101.65', 'b', NOW() - INTERVAL '55 hours'),
(17, '172.121.22.75', 'b', NOW() - INTERVAL '54 hours'),
(17, '192.168.112.85', 'a', NOW() - INTERVAL '53 hours'),
(17, '10.102.102.95', 'b', NOW() - INTERVAL '52 hours'),
(17, '172.122.23.105', 'b', NOW() - INTERVAL '51 hours'),
(17, '192.168.113.115', 'b', NOW() - INTERVAL '50 hours');

-- Poll 18 votes (Closed - College athlete salaries)
INSERT INTO votes (poll_id, user_ip, option, voted_at) VALUES
(18, '192.168.120.30', 'a', NOW() - INTERVAL '71 hours'),
(18, '10.110.110.40', 'a', NOW() - INTERVAL '70 hours'),
(18, '172.130.24.50', 'a', NOW() - INTERVAL '69 hours'),
(18, '192.168.121.60', 'b', NOW() - INTERVAL '68 hours'),
(18, '10.111.111.70', 'a', NOW() - INTERVAL '67 hours'),
(18, '172.131.25.80', 'a', NOW() - INTERVAL '66 hours'),
(18, '192.168.122.90', 'a', NOW() - INTERVAL '65 hours'),
(18, '10.112.112.100', 'b', NOW() - INTERVAL '64 hours'),
(18, '172.132.26.110', 'a', NOW() - INTERVAL '63 hours'),
(18, '192.168.123.120', 'a', NOW() - INTERVAL '62 hours'),
(18, '10.113.113.130', 'a', NOW() - INTERVAL '61 hours'),
(18, '172.133.27.140', 'b', NOW() - INTERVAL '60 hours'),
(18, '192.168.124.150', 'a', NOW() - INTERVAL '59 hours');

-- Poll 19 votes (Closed - Lab-grown meat)
INSERT INTO votes (poll_id, user_ip, option, voted_at) VALUES
(19, '192.168.130.35', 'a', NOW() - INTERVAL '39 hours'),
(19, '10.120.120.45', 'b', NOW() - INTERVAL '38 hours'),
(19, '172.140.28.55', 'a', NOW() - INTERVAL '37 hours'),
(19, '192.168.131.65', 'a', NOW() - INTERVAL '36 hours'),
(19, '10.121.121.75', 'b', NOW() - INTERVAL '35 hours'),
(19, '172.141.29.85', 'a', NOW() - INTERVAL '34 hours'),
(19, '192.168.132.95', 'b', NOW() - INTERVAL '33 hours'),
(19, '10.122.122.105', 'a', NOW() - INTERVAL '32 hours');

-- Poll 20 votes (Closed - Legacy sequels)
INSERT INTO votes (poll_id, user_ip, option, voted_at) VALUES
(20, '192.168.140.40', 'a', NOW() - INTERVAL '35 hours'),
(20, '10.130.130.50', 'a', NOW() - INTERVAL '34 hours'),
(20, '172.150.30.60', 'b', NOW() - INTERVAL '33 hours'),
(20, '192.168.141.70', 'a', NOW() - INTERVAL '32 hours'),
(20, '10.131.131.80', 'a', NOW() - INTERVAL '31 hours'),
(20, '172.151.31.90', 'a', NOW() - INTERVAL '30 hours'),
(20, '192.168.142.100', 'b', NOW() - INTERVAL '29 hours'),
(20, '10.132.132.110', 'a', NOW() - INTERVAL '28 hours'),
(20, '172.152.32.120', 'a', NOW() - INTERVAL '27 hours'),
(20, '192.168.143.130', 'a', NOW() - INTERVAL '26 hours'),
(20, '10.133.133.140', 'b', NOW() - INTERVAL '25 hours'),
(20, '192.168.144.150', 'a', NOW() - INTERVAL '24 hours');

