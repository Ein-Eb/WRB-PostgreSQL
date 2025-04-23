-- All WRB features are based on World Reference Base for Soil Resources 2022 (corrections as of 2022-12-18)
-- Sorting the name elements (qualifiers, subqualifiers) requires to consider the RSG-dependent qualifier position (principal, supplementary and non-listed qualifiers); for the principal qualifiers, this is explicitly defined for each RSG independently; supplementary qualifiers according to the alphabet, disregarding specifiers; non-listed qualifiers at the end of the supplementary qualifiers (here, in addition to WRB, two or more non-listed, applicable qualifiers are also ordered alphabetically)
-- A general WRB rule is that redundant information (nmae element) is not added to the soil name. Redundancy can occur between qualifiers and between RSG and qualifiers; therefore, some qualifiers have been labelled 'not applicable' for some RSGs.
-- Further non-applicability arises due to logical reasons from the WRB key. This has been labelled in v_q_ord with the reason for non-applicability.
-- Some qualifiers are complementary complete, which means one of their group applies in any case; if they are missing, this is indicated in the resulting soil name in [ by listing those from which one should apply 

-- Naming conventions in this DB: 
--	table names start with ct_ if they hold control information for WRB soil names; 
--	data tables start with t_; 
--	WRB words:
--	r means RSG, 
--	q means (sub)qualifier, 
--	s means specifier; 
--	princ means principal
--	supp means supplementary
--	Other words:
--	abbr for code/abbreviation, 
--	cond for condition, 
--	corr for corrected,
--	gr for group, 
--	ord for order, 
--	pos for position, 
--	prep for preparation,
--	rel for relation, 
--	sel for selection,
--	soil prof for soil profile,
--  tx for (soil) texture

-- Drop all tables for a complete new database setup
DROP TABLE IF EXISTS ct_r CASCADE;
DROP TABLE IF EXISTS ct_s CASCADE;
DROP TABLE IF EXISTS ct_q_cond_gr CASCADE;
DROP TABLE IF EXISTS ct_q_role CASCADE;
DROP TABLE IF EXISTS ct_q CASCADE;
DROP TABLE IF EXISTS ct_q_ord CASCADE; 

-- Drop example data tables
DROP TABLE IF EXISTS public.t_soil_prof CASCADE;
DROP TABLE IF EXISTS t_soil_q CASCADE;


-- ct_r holds all Reference Soil Group (RSG) names in the order of the WRB key
CREATE TABLE ct_r (
    rid integer UNIQUE NOT NULL,
    r VARCHAR(100) NOT NULL,
	r_abbr VARCHAR(2));

COPY ct_r FROM 'C:\Temp\ct_r.csv' WITH csv;
	
-- ct_s holds all all depth-related specifiers plus Supra and Thapto (and the only possible combination Thaptobathy) with order rank correction if used with texture qualifiers
CREATE TABLE ct_s (
    sid integer UNIQUE NOT NULL,
    s VARCHAR(100) NOT NULL,
	s_abbr VARCHAR(4) NOT NULL,
	s_pos_corr integer,
	s_pos_corr_new integer, 
	s_tx_pos integer, 
	s_pos_inc integer);

COPY ct_s FROM 'C:\Temp\ct_s.csv' WITH csv;

-- ct_q_role holds the possible qualifier roles (principal, supplementary, texture, not listed, etc.)
CREATE TABLE ct_q_role (
    q_roleid integer UNIQUE NOT NULL,
    q_role VARCHAR(100) NOT NULL,
    q_role_abbr VARCHAR(3));
	
	INSERT INTO ct_q_role (q_roleid, q_role, q_role_abbr) VALUES
		(10,'principal','pr'::text), 
		(11,'principal, conditionally mandatory','prc'::text), 
		(20,'supplementary', 'su'::text), 
		(21,'supplementary, conditionally mandatory', 'suc'::text), 
		(30,'texture','tx'::text), 
		(40,'not listed','nl'::text), 
		(45,'not listed - restricted to specifier by logic','nlr'::text), 
		(60,'not appliccable','na'::text), 
		(61,'not applicable - restricted to another RSG','nar'::text), 
		(62,'not applicable - keys out earlier with another RSG','nak'::text), 
		(63,'not applicable - explicitly excluded from RSG by definition','nae'::text), 
		(64,'not applicable - redundant information with RSG','nad'::text), 
		(65,'not applicable - excluded through RSG definition by logic','nal'::text);


-- ct_q_cond_gr provides the groups of qualifiers of each RSG that are conditionally mandatory
CREATE TABLE ct_q_cond_gr (
    r_q_cond_gr_id  integer PRIMARY KEY, 
    rid integer REFERENCES ct_r (rid) NOT NULL,
    q_roleid integer REFERENCES ct_q_role (q_roleid) NOT NULL,
	q_list VARCHAR(255) NOT NULL, 
	q_abbr_list VARCHAR(50) NOT NULL, 
	q_pos integer);
	
COPY ct_q_cond_gr FROM 'C:\Temp\ct_q_cond_gr.csv' WITH csv;

-- ct_q holds all qualifiers and all subqualifiers with a given definition; in the specifier datafields is indicated with which depth-related specifiers they can be combined; and the ordering rank if used as a supplementary qualifier (which is according th the alphabet, using the qualifier, but not the subqualifier name)
-- 		field q_gr_type: Group type, 1 no combination possible, 2 with differing specifiers possible, 3 redundant information, 4 with differing specifiers possible, order from top to bottom in soil profile (texture qualifiers); 5 negative group preference member redundant if not combined)
CREATE TABLE ct_q
(
    qid integer NOT NULL,
    q VARCHAR(50) NOT NULL,
    q_prefix VARCHAR(25), 
	q_abbr VARCHAR(3),
    qid_rel integer REFERENCES ct_q (qid),
    q_mgr integer, 							-- qualifier main group, for identifying missing conditional qualifiers 
	q_gr integer,
    q_gr_pref integer,
    q_gr_type integer,
    q_supp_abs_order_pos integer,
    q_rel varchar(255),
    r_restr VARCHAR(255),
    q_s_rule integer,
    q_s_rule_note VARCHAR(255),
    q_limit boolean,
    q_gr_supra integer,						-- group for the supra subqualifier (no more than one of these (sub)qualifiers to be combined with Supra for each soil profile)
	epi boolean,
    endo boolean,
    amphi boolean,
    poly boolean,
    ano boolean,
    panto boolean,
    kato boolean,
    supra boolean,
    bathy boolean,
    thapto boolean,
    CONSTRAINT t_qual_pkey PRIMARY KEY (qid),
    CONSTRAINT t_qual_check CHECK (q::text <> ''::text)
);

COPY ct_q FROM 'C:\Temp\ct_q.csv' WITH csv;

-- ct_q_ord holds for each RSG for each (sub)qualifier of ct_q whether it is a principal qualifier (with its ordering rank as given in the WRB RSG key)
-- ct_q.q_gr_type: Group type 
--		1 no combination possible, 
--		2 with differing specifiers possible, 
--		3 redundant information, 
--		4 with differing specifiers possible, order from top to bottom in soil profile (texture qualifiers); 
--		5 negative group preference member, i.e. redundant if not combined with other subqualifier of the same absolute preference number)
CREATE TABLE ct_q_ord
(
	rid integer,
    qid integer,
    q_roleid integer,
    q_pos integer,
	r_q_cond_gr_id integer REFERENCES ct_q_cond_gr (r_q_cond_gr_id), 
    q_gr integer,
    q_gr_pref integer,
    q_gr_pref_cond VARCHAR (255),
    q_gr_type integer,
    q_rel integer,
    sid integer,
    CONSTRAINT ct_q_ord_rid_fkey FOREIGN KEY (rid)
        REFERENCES public.ct_r (rid) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,
    CONSTRAINT ct_q_ord_sid_fkey FOREIGN KEY (sid)
        REFERENCES public.ct_s (sid) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,
    CONSTRAINT ct_q_roleid_fkey FOREIGN KEY (q_roleid)
        REFERENCES public.ct_q_role (q_roleid) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION
);

COPY ct_q_ord FROM 'C:\Temp\ct_q_ord.csv' WITH csv;

-- t_soil_prof holds soil profiles (here with ID and RSG only)
CREATE TABLE IF NOT EXISTS public.t_soil_prof
(
    profid integer NOT NULL,
    rid integer,
    CONSTRAINT t_soil_prof_pkey PRIMARY KEY (profid),
    CONSTRAINT t_soil_prof_rsg_fkey FOREIGN KEY (rid)
        REFERENCES public.ct_r (rid) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION
);

COPY t_soil_prof FROM 'C:\Temp\Testdaten_soph_Prof.csv' WITH csv;


-- t_soil_q holds all (sub)qualifiers as defined in ct_q, possibly with a specifier, as a list
CREATE TABLE public.t_soil_q
(
    profid integer,
    qid integer,
    sid integer,
	sqid integer UNIQUE NOT NULL,
	order_pos integer, -- texture-related (sub-)qualifiers need possibly information on their order
	sid_c integer GENERATED ALWAYS AS (CASE WHEN sid Is Null THEN 0 ELSE sid END) STORED, -- helps to identify dublets in the cascade of views
	sid_d integer GENERATED ALWAYS AS (CASE WHEN sid Is Null THEN 0 ELSE (CASE WHEN sid BETWEEN 1 AND 8 THEN 0 ELSE sid END) END) STORED, -- helps to identify qualifiers for which several depth-related specifiers are used in the cascade of views
    CONSTRAINT t_soil_q_profid_fkey FOREIGN KEY (profid)
        REFERENCES public.t_soil_prof (profid) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION,
    CONSTRAINT t_soil_q_sid_fkey FOREIGN KEY (sid)
        REFERENCES public.ct_s (sid) MATCH SIMPLE
        ON UPDATE NO ACTION
        ON DELETE NO ACTION
);

COPY t_soil_q FROM 'C:\Temp\Testdaten_soph_Qual.csv' WITH csv;


-- v_r provides an ordered list of RSGs from ct_r
DROP VIEW IF EXISTS v_r CASCADE;
CREATE MATERIALIZED VIEW v_r AS
SELECT ct_r.rid, 
	ct_r.r, 
	ct_r.r_abbr
FROM ct_r
ORDER BY ct_r.rid;

-- v_s provides an ordered list of all depth-related specifiers (from ct_s)
DROP MATERIALIZED VIEW IF EXISTS v_s CASCADE;
CREATE VIEW  v_s AS
SELECT ct_s.s, 
	ct_s.s_abbr, 
	ct_s.s_pos_corr, 
	ct_s.s_tx_pos, 
	ct_s.s_pos_inc, 
	ct_s.sid
FROM ct_s;

-- v_q provides the (sub)qualifiers of ct_q, but gives parent (sub)qualifier as clear text as well
DROP VIEW IF EXISTS v_q CASCADE;
CREATE MATERIALIZED VIEW v_q AS
SELECT ct_q.qid, 
	ct_q.q, 
	ct_q.q_prefix, 
	ct_q.q_abbr, 
	ct_q.q_supp_abs_order_pos, 
	ct_q.q_mgr, 
	ct_q.q_gr, 
	ct_q.q_gr_pref, 
	ct_q.q_gr_type, 
	ct_q.qid_rel AS q_rel, 
	ct_q_1.q AS q_rel_q, 
	ct_q.r_restr, 
	ct_q.q_s_rule, 
	ct_q.q_limit, 
	ct_q.q_gr_supra, 
	ct_q.Epi, ct_q.Endo, 
	ct_q.Amphi, ct_q.Poly, 
	ct_q.Ano, ct_q.Panto, 
	ct_q.Kato, ct_q.Bathy, 
	ct_q.Thapto, ct_q.Supra
FROM ct_q LEFT JOIN ct_q AS ct_q_1 ON ct_q.qid_rel = ct_q_1.qid
ORDER BY ct_q.qid;

-- v_q_all provides a list of all subqualifiers (including depth-related subqualifiers) that exist in WRB 2022; considers which (sub)qualifiers can be combined with which depth-related specifiers as defined in ct_q
DROP VIEW IF EXISTS v_q_all CASCADE;
CREATE MATERIALIZED VIEW v_q_all AS
(SELECT v_q.qid AS sqid, 
    v_q.qid,
    NULL::integer AS sid,
    v_q.q,
    v_q.q_abbr,
    v_q.q_s_rule AS s_comb_type,
    v_q.q_rel,
    (v_q.q_rel IS NOT NULL) AS q_subqual_def
  FROM v_q
  WHERE (v_q.q_rel IS NULL)) 
UNION (SELECT (v_q.qid) AS sqid,
    v_q.qid,
    NULL AS sid,
    v_q.q,
    v_q.q_abbr,
    v_q.q_s_rule AS s_comb_type,
    v_q.q_rel,
    (v_q.q_rel_q IS NOT NULL) AS q_subqual_def
   FROM v_q
  WHERE (v_q.q_rel IS NOT NULL)) 
UNION (SELECT ((v_q.qid) + 1) AS sqid,
    v_q.qid,
    1::integer AS sid,
    ('Amphi'::text||LOWER(v_q.q)::text) AS q,
    ((v_q.q_abbr::text)||'m'::text) AS q_abbr,
    v_q.q_s_rule AS s_comb_type,
    (v_q.qid) AS q_rel,
    (v_q.q_rel_q IS NOT NULL) AS q_subqual_def
   FROM v_q
  WHERE (v_q.amphi = true)) 
UNION (SELECT ((v_q.qid) + 2) AS sqid,
    v_q.qid,
    2::integer AS sid,
    ('Ano'::text||LOWER(v_q.q)::text) AS q,
    ((v_q.q_abbr::text)||'a'::text) AS q_abbr,
    v_q.q_s_rule AS s_comb_type,
    (v_q.qid) AS q_rel,
    (v_q.q_rel_q IS NOT NULL) AS q_subqual_def
   FROM v_q
  WHERE (v_q.ano = true)) 
UNION (SELECT ((v_q.qid) + 3) AS sqid,
    v_q.qid,
    3::integer AS sid,
    ('Bathy'::text||LOWER(v_q.q)::text) AS q,
    ((v_q.q_abbr::text)||'d'::text) AS q_abbr,
    v_q.q_s_rule AS s_comb_type,
    (v_q.qid) AS q_rel,
    (v_q.q_rel_q IS NOT NULL) AS q_subqual_def
   FROM v_q 
  WHERE (v_q.bathy = true)) 
UNION (SELECT ((v_q.qid) + 4) AS sqid,
    v_q.qid,
    4::integer AS sid,
    ('Endo'::text||LOWER(v_q.q)::text) AS q,
    ((v_q.q_abbr::text)||'n'::text) AS q_abbr,
    v_q.q_s_rule AS s_comb_type,
    (v_q.qid) AS q_rel,
    (v_q.q_rel_q IS NOT NULL) AS q_subqual_def
   FROM v_q 
  WHERE (v_q.endo = true)) 
UNION (SELECT ((v_q.qid) + 5) AS sqid,
    v_q.qid,
    5::integer AS sid,
    ('Epi'::text||LOWER(v_q.q)::text) AS q,
    ((v_q.q_abbr::text)||'p'::text) AS q_abbr,
    v_q.q_s_rule AS s_comb_type,
    (v_q.qid) AS q_rel,
    (v_q.q_rel_q IS NOT NULL) AS q_subqual_def 
   FROM v_q 
  WHERE (v_q.epi = true)) 
UNION (SELECT ((v_q.qid) + 6) AS sqid,
    v_q.qid,
    6::integer AS sid,
    ('Kato'::text||LOWER(v_q.q)::text) AS q,
    ((v_q.q_abbr::text)||'k'::text) AS q_abbr,
    v_q.q_s_rule AS s_comb_type,
    (v_q.qid) AS q_rel,
    (v_q.q_rel_q IS NOT NULL) AS q_subqual_def 
   FROM v_q 
  WHERE (v_q.kato = true)) 
UNION (SELECT ((v_q.qid) + 7) AS sqid,
    v_q.qid,
    7::integer AS sid,
    ('Panto'::text||LOWER(v_q.q)::text) AS q,
    ((v_q.q_abbr::text)||'e'::text) AS q_abbr,
    v_q.q_s_rule AS s_comb_type,
    (v_q.qid) AS q_rel,
    (v_q.q_rel_q IS NOT NULL) AS q_subqual_def
   FROM v_q
  WHERE (v_q.panto = true)) 
UNION (SELECT ((v_q.qid) + 8) AS sqid,
    v_q.qid,
    8::integer AS sid,
    ('Poly'::text||LOWER(v_q.q)::text) AS q,
    ((v_q.q_abbr::text)||'y'::text) AS q_abbr,
    v_q.q_s_rule AS s_comb_type,
    (v_q.qid) AS q_rel,
    (v_q.q_rel_q IS NOT NULL) AS q_subqual_def
   FROM v_q
  WHERE (v_q.poly = true)) 
UNION (SELECT ((v_q.qid) + 9) AS sqid,
    v_q.qid,
    9::integer AS sid,
    ('Supra'::text||LOWER(v_q.q)::text) AS q,
    ((v_q.q_abbr::text)||'s'::text) AS q_abbr,
    v_q.q_s_rule AS s_comb_type,
    (v_q.qid) AS q_rel,
    (v_q.q_rel_q IS NOT NULL) AS q_subqual_def
   FROM v_q
  WHERE (v_q.supra = true)) 
UNION (SELECT ((v_q.qid) + 10) AS sqid,
    v_q.qid,
    10::integer AS sid,
    ('Thapto'::text||LOWER(v_q.q)::text) AS q,
    ((v_q.q_abbr::text)||'b'::text) AS q_abbr,
    v_q.q_s_rule AS s_comb_type,
    (v_q.qid) AS q_rel,
    (v_q.q_rel_q IS NOT NULL) AS q_subqual_def
   FROM v_q
  WHERE (v_q.thapto = true)) 
UNION (SELECT (((v_q.qid) + 10) + 13) AS sqid,
    v_q.qid,
    23::integer AS sid,
    ('Thaptobathy'::text||LOWER(v_q.q)::text) AS q, 
    ((v_q.q_abbr::text)||'db'::text) AS q_abbr, 
    v_q.q_s_rule AS s_comb_type, 
    (v_q.qid) AS q_rel, 
    (v_q.q_rel_q IS NOT NULL) AS q_subqual_def 
  FROM v_q 
  WHERE ((v_q.bathy = true) AND (v_q.thapto = true)));

-- v_soil_prof provides a list of soil profiles with ID and RSG from t_soil_prof (this view needs to be adaptated if this solution is integreted into an existing soil profile database when t_soil_prof is replaced by the existing soil profile data table)
CREATE MATERIALIZED VIEW v_soil_prof AS
SELECT t_soil_prof.profid, 
	t_soil_prof.rid 
FROM t_soil_prof;

-- v_q_ord provides all fields of ct_q_ord
CREATE MATERIALIZED VIEW v_q_ord AS 
SELECT ct_q_ord.rid, 
	ct_q_ord.qid, 
	ct_q_ord.q_roleid AS q_role, 
	ct_q_ord.q_pos, 
	ct_q_ord.r_q_cond_gr_id, 
	ct_q_ord.q_gr, 
	ct_q_ord.q_gr_pref, 
	ct_q_ord.q_gr_type, 
	ct_q_ord.sid, 
	ct_q_ord.q_gr_pref_cond 
FROM ct_q_ord 
ORDER BY ct_q_ord.rid, ct_q_ord.qid;

-- Mutually exclusive Supra- subqualifiers are filtered with the following two views
-- v_soil_q_supra_prep contains all profiles and the group number of mutually exclusive qualifiers for which too many Supra subqualifiers have been assigned
 CREATE VIEW v_soil_q_supra_prep AS 
(SELECT t_soil_q.profid, v_q.q_gr_supra 
	FROM t_soil_q INNER JOIN v_q ON (t_soil_q.qid=v_q.qid) 
	WHERE t_soil_q.sid = 9 -- Supra- 
	GROUP BY t_soil_q.profid, v_q.q_gr_supra 
	HAVING COUNT(t_soil_q.sid)>1);

-- v_soil_q_supra_sel holds all those Supra sub-qualifiers that are allowed to be combined with the respective RSG
-- v_soil_q_supra_sel checks whether the (sub-)qualifier is applicable for the RSG and combines the (sub)qualifier name with the Supra specifier to form the Supra subqualifier
CREATE VIEW v_soil_q_supra_sel AS 
(SELECT t_soil_q.profid, 
	t_soil_q.qid, 
	t_soil_q.sid, 
	v_s.s, 
	v_q.q,
	t_soil_q.order_pos, 
	--CASE WHEN t_soil_q.order_pos Is Not Null THEN (1010+(Select Count (*) FROM t_soil_q as Tmp WHERE Tmp.profid=t_soil_q.profid And Tmp.order_pos < t_soil_q.order_pos)+1) ELSE (1020+(Select Count (*) FROM t_soil_q AS Tmp WHERE Tmp.profid=t_soil_q.profid And Tmp.sqid < t_soil_q.sqid)+1) END AS q_pos, 
	t_soil_q.sqid
FROM ((((((t_soil_q LEFT JOIN v_soil_q_supra_prep ON t_soil_q.profid = v_soil_q_supra_prep.profid) INNER JOIN v_q ON t_soil_q.qid = v_q.qid) LEFT JOIN v_s ON t_soil_q.sid = v_s.sid) INNER JOIN v_soil_prof ON t_soil_q.profid = v_soil_prof.profid) INNER JOIN v_q_ord ON (t_soil_q.qid = v_q_ord.qid) AND (v_soil_prof.rid = v_q_ord.rid))) 
WHERE v_q.supra=True And t_soil_q.sid = 9 AND ((v_q_ord.q_role)<60) AND ((v_soil_q_supra_prep.profid) Is Null));


-- v_soil_q contains all (sub)qualifiers that have been allocated by the DB user to each soil profile, 
--		except the qualifier Haplic (qid = 3120 in ct_q), which needs to be handled separately, because it denotes for some RSGs that that no other principal qualifier applies; 
--  	this can only be tested after checking which qualifiers have validly been allocated 
--		and without those depth-related subqualifiers (excl. Supra-, Bathy-) of the same qualifier that have a higher specifier ID; because each qualifier can have only one of 
--		these specifiers in one soil profile
--		All (sub)qualifiers except those with Bathy or Thapro are filtered for too many occurrences; then all Bathy and Thapto subqualifiers as well as all filtered Supra subqualifiers are added
CREATE MATERIALIZED VIEW v_soil_q AS 
(SELECT DISTINCT t_soil_q.profid, 
	t_soil_q.qid, 
	min (t1.sid) AS sid, 
	-- For qualifiers Fibric, Hemic and Sapric a order position order_pos is added, if not explicitly stated, in order to bring them in the right order if needed; otherwise, order_pos is kept, even if NULL:
	CASE WHEN (MIN(t1.order_pos) IS NOT NULL OR MIN(t1.qid) NOT IN (2190, 3150, 8190)) THEN MIN(t1.order_pos) WHEN MIN(t1.qid) IN (2190, 3150, 8190) THEN ((SELECT count (qid)+MIN(Temp_s.s_pos_corr) FROM t_soil_q As Temp LEFT JOIN v_S AS Temp_s ON (Temp.sid=(Temp_s.sid)) WHERE (Temp.qid IN (2190, 3150, 8190) AND (Temp.sqid < t1.sqid) And (Temp.profid = t_soil_q.profid)))+1) ELSE NULL END AS order_pos, 
	min(t_soil_q.sqid) AS sqid 
FROM t_soil_q INNER JOIN (SELECT * FROM t_soil_q WHERE ((t_soil_q.sid NOT IN (3,9,10)) OR t_soil_q.sid IS NULL)) AS t1 ON (t1.profid=t_soil_q.profid AND t_soil_q.qid=t1.qid) LEFT JOIN v_s ON (t_soil_q.sid = v_s.sid)  
WHERE ((t_soil_q.qid)<>3120) 
GROUP BY t_soil_q.profid, t_soil_q.qid, t1.sqid  
HAVING t1.sqid=min(t_soil_q.sqid)  
ORDER BY t_soil_q.profid, t_soil_q.qid) 
UNION (SELECT DISTINCT t_soil_q.profid, 
	t_soil_q.qid, 
	t_soil_q.sid, 
	t_soil_q.order_pos, 
	t_soil_q.sqid 
FROM t_soil_q 
WHERE t_soil_q.sid IN (3,10,11) AND ((t_soil_q.qid)<>3120) 
ORDER BY t_soil_q.profid, t_soil_q.qid) 
UNION (SELECT DISTINCT v_soil_q_supra_sel.profid, 
	v_soil_q_supra_sel.qid, 
	v_soil_q_supra_sel.sid, 
	v_soil_q_supra_sel.order_pos, 
	v_soil_q_supra_sel.sqid 
FROM v_soil_q_supra_sel);

-- The (sub-)qualifiers of Qualifier Group Type (q_gr_type) 4 (those related to the texture and to the degree of peat decomposition) are used differently than all other qualifiers, because they 
--		i) they are - in any depth range - mutually exclusive, which implicitly means that they
--			a. have restrictions on their number and 
--			b. on the use of depth-related specifiers
-- and the (sub-)qualifiers related to texture are in addition used in another way than all other supplementary qualifiers, because they
--		ii) are to be ordered according to their sequence from top to bottom in the soil profile 
-- Because it is impossible to determine the position of a Poly- subqualifier without further horizon information, it is placed here directly after a qualifier without specifier
-- The (sub-)qualifier order implemented here is Supra- < Ano- < Epi- < Poly- < Kato- < Amphi- < without specifier < Endo- <  Bathy- = Thaptobathy- 
-- Per soil profile,
-- 1. Each qualifier can be assigned with one specifier only, except with Supra-, Bathy- in addition
-- The view contains all profiles that have errors in this respect
CREATE VIEW v_soil_txq_prep1 AS 
SELECT v_soil_q.profid, 
	COUNT (v_soil_q.sid) AS s_number 
FROM v_soil_q INNER JOIN v_q ON (v_soil_q.qid=v_q.qid) 
WHERE v_q.q_gr_type = 4 AND v_soil_q.sid NOT IN (3,9,10) 
GROUP BY v_soil_q.profid, v_soil_q.sid
HAVING COUNT(v_soil_q.sid)>1;

-- 2. Each specifier - except Poly-, Bathy- or Thaptobathy- - can be combined with one of the texture-related qualifiers only
-- This is already handled in v_soil_q.

-- 3. a) When one qualifier has the Panto- specifier, no other qualifier can be assigned, except if combined with Bathy- or Thaptobathy-;
--		and when a qualifier has the Ano- or Kato- specifier, respectively, can there only be - except if combined with Bathy- or Thaptobathy- - one other qualifier with the Endo- or Poly- specifier, or with the Epi- or Poly- specifier, respectively
-- This view contains all profiles that have errors in this respect 
CREATE VIEW v_soil_txq_prep3a AS 
(SELECT v.profid, 
	v_soil_q.qid, 
	v_soil_q.sid 
FROM (SELECT DISTINCT v_soil_q.qid AS qid, v_soil_q.sid AS sid, v_soil_q.profid AS profid FROM v_soil_q INNER JOIN v_q ON (v_soil_q.qid=v_q.qid) WHERE v_q.q_gr_type = 4 AND v_soil_q.sid=7) AS v INNER JOIN v_soil_q ON (v.profid=v_soil_q.profid)   
WHERE (v_soil_q.qid IN (510,1200,4230,8340)) AND (v_soil_q.sid NOT IN (3,7,10) OR v_soil_q.sid IS Null)) 
UNION (
SELECT v.profid, 
	v_soil_q.qid, 
	v_soil_q.sid 
FROM (SELECT DISTINCT v_soil_q.qid AS qid, v_soil_q.sid AS sid, v_soil_q.profid AS profid FROM v_soil_q INNER JOIN v_q ON (v_soil_q.qid=v_q.qid) WHERE v_q.q_gr_type = 4 AND v_soil_q.sid=2) AS v INNER JOIN v_soil_q ON (v.profid=v_soil_q.profid)   
WHERE v_soil_q.sid NOT IN (2,3,4,7,8,9,10) OR v_soil_q.sid IS Null) 
UNION (
	SELECT v.profid, 
	v_soil_q.qid, 
	v_soil_q.sid 
FROM (SELECT DISTINCT v_soil_q.qid AS qid, v_soil_q.sid AS sid, v_soil_q.profid AS profid FROM v_soil_q INNER JOIN v_q ON (v_soil_q.qid=v_q.qid) WHERE v_q.q_gr_type = 4 AND v_soil_q.sid=6) AS v INNER JOIN v_soil_q ON (v.profid=v_soil_q.profid)   
--WHERE v_soil_q.sid NOT IN (2,3,5,6,7,8,10) OR v_soil_q.sid IS Null);
WHERE v_soil_q.sid NOT IN (3,5,6,7,8,9,10) OR v_soil_q.sid IS Null);

-- 3. b) If three qualifiers (except those combined with Bathy-, Thaptobathy-) are assigned, they must be used without specifier or with once each of Epi-, Amphi- or Endo-, or with the Poly- specifier;
--		and not more than three (sub-)qualifiers (except those combined with Bathy-, Thaptobathy-) can be assigned; additionally, if one Panto- subqualifier is assigned, no other 
--			(sub-)qualifier can be assigned
-- This view contains all profiles that have errors in this respect
CREATE VIEW v_soil_txq_prep3b AS 
((SELECT v_soil_q.profid 
FROM v_soil_q INNER JOIN v_q ON (v_soil_q.qid=v_q.qid) 
WHERE v_q.q_gr_type = 4 AND (v_soil_q.sid NOT IN (3,8,10,11) OR v_soil_q.sid IS NULL) 
GROUP BY v_soil_q.profid 
HAVING COUNT(v_soil_q.qid)>3) 
UNION (SELECT v_soil_q.profid 
FROM (SELECT v_soil_q.profid FROM v_soil_q INNER JOIN v_q ON (v_soil_q.qid=v_q.qid) WHERE v_q.q_gr_type = 4 AND (v_soil_q.sid NOT IN (3,10,11) OR v_soil_q.sid IS NULL) GROUP BY v_soil_q.profid HAVING COUNT(v_soil_q.qid)>=3) AS v LEFT JOIN v_soil_q ON (v.profid=v_soil_q.profid) LEFT JOIN v_q ON (v_soil_q.qid=v_q.qid) 
WHERE v_q.q_gr_type = 4 AND (v_soil_q.sid NOT IN (1,3,4,5,8,10) AND v_soil_q.sid IS NOT NULL) 
ORDER BY v_soil_q.profid) 
-- Panto-
UNION (SELECT v_soil_q.profid FROM v_soil_q INNER JOIN (SELECT v_soil_q.profid FROM v_soil_q INNER JOIN v_q ON (v_soil_q.qid=v_q.qid) WHERE v_q.q_gr_type = 4 AND (v_soil_q.sid = 7) ORDER BY v_soil_q.profid) AS v ON (v_soil_q.profid=v.profid) INNER JOIN v_q ON (v_soil_q.qid=v_q.qid) 
WHERE v_q.q_gr_type = 4 AND (v_soil_q.sid IN (1,2,4,5,6,8) OR v_soil_q.sid IS NULL))) ;


-- v_soil_txq_corr_sel holds all those texture-related (sub-)qualifiers that are allowed to be combined with the respective RSG
-- v_soil_txq_corr_sel checks whether the (sub-)qualifier is applicable for the RSG and combines the qualifier name with the depth-related specifier to form the respective subqualifier
CREATE MATERIALIZED VIEW v_soil_txq_corr_sel AS 
(SELECT v_soil_q.profid, 
	v_soil_q.qid, 
	CASE WHEN v_soil_q.sid Is Not Null THEN s||LOWER(q) ELSE q END AS q_corr, 
	v_q.q_abbr||CASE WHEN v_soil_q.sid Is Not Null THEN v_s.s_abbr ELSE '' END AS q_abbr_corr, 
	v_soil_q.sid, 
	v_s.s, 
	v_q.q, 
 	CASE WHEN v_soil_q.sid Is Null THEN 
 		(CASE WHEN v_soil_q.order_pos Is Not Null THEN (1010+(Select Count (*) FROM v_soil_q as Tmp WHERE Tmp.profid=v_soil_q.profid And Tmp.order_pos < v_soil_q.order_pos)+1) 
		 		ELSE (1020+(Select Count (*) FROM v_soil_q AS Tmp WHERE Tmp.profid=v_soil_q.profid And Tmp.sqid < v_soil_q.sqid)+1) END) 
 		ELSE CASE WHEN v_soil_q.sid=8 THEN (1025+(Select Count (*) FROM v_soil_q AS Tmp WHERE Tmp.profid=v_soil_q.profid And Tmp.sqid < v_soil_q.sqid)+1) ELSE v_s.s_tx_pos END END AS q_pos, 
	v_q_ord.q_role, 
	v_q.q_gr AS q_gr_sel, 
	v_q.q_gr_pref AS q_gr_pref_sel, 
	v_q.q_gr_type AS q_gr_type_sel, 
	v_q.q_supp_abs_order_pos AS q_pos_supp, 
	v_soil_q.sqid
FROM ((((((v_soil_q LEFT JOIN v_soil_txq_prep1 ON v_soil_q.profid = v_soil_txq_prep1.profid) LEFT JOIN v_soil_txq_prep3a ON (v_soil_q.sid = v_soil_txq_prep3a.sid) AND (v_soil_q.qid = v_soil_txq_prep3a.qid) AND (v_soil_q.profid = v_soil_txq_prep3a.profid)) LEFT JOIN v_soil_txq_prep3b ON v_soil_q.profid = v_soil_txq_prep3b.profid) INNER JOIN v_q ON v_soil_q.qid = v_q.qid) LEFT JOIN v_s ON v_soil_q.sid = v_s.sid) INNER JOIN v_soil_prof ON v_soil_q.profid = v_soil_prof.profid) INNER JOIN v_q_ord ON (v_soil_q.qid = v_q_ord.qid) AND (v_soil_prof.rid = v_q_ord.rid)
WHERE (v_q.q_gr_type=4 AND (v_q_ord.q_role < 60 OR v_soil_q.sid IN (3,11))) AND ((((v_soil_txq_prep1.profid) Is Null) AND ((v_soil_txq_prep3a.profid) Is Null)) OR ((v_q.q_gr_type=4) AND ((v_soil_q.sid) Is Null) AND ((v_q_ord.q_role)<60))) AND ((v_soil_txq_prep3b.profid) Is Null OR v_soil_q.sid = 7));

-- v_soil_q_corr_indep selects corrected (sub)qualifiers that apply independently of further applying (sub)qualifiers 
-- (which are complemented by those (sub)qualifiers identified by v_soil_q_corr_add)
CREATE OR REPLACE VIEW v_soil_q_corr_indep AS 
(SELECT DISTINCT 
	v_soil_q.profid, 
 	v_q_ord.qid, 
	CASE WHEN v_q.q_prefix IS NULL THEN v_s.s||LOWER(v_q.q) ELSE v_q.q_prefix||v_s.s||LOWER(v_q_1.q) END AS q_corr, 
	v_q.q_abbr::text||v_s.s_abbr::text AS q_abbr_corr, 
	v_soil_q.sid, 
	v_s.s, 
 	v_q.q, 
	CASE WHEN v_q_ord.q_pos Is Null AND v_q_ord.q_role>=40 THEN (20000+3*v_q.q_supp_abs_order_pos+v_s.sid-3) 
		WHEN v_q_ord.q_pos Is Null THEN v_q.q_supp_abs_order_pos 
		WHEN v_soil_q.sid IN (3,10,11) THEN v_q.q_supp_abs_order_pos 
		ELSE v_q_ord.q_pos END AS q_pos, 
	v_q_ord.q_role, 
	COALESCE (v_q_ord.q_gr,v_q.q_gr,v_q.q_mgr) AS q_gr_sel, 
	CASE WHEN v_q_ord.q_gr Is Not Null THEN v_q_ord.q_gr_pref ELSE CASE WHEN v_q.q_gr_pref IS NULL THEN 1::int ELSE v_q.q_gr_pref END END AS q_gr_pref_sel, 
--	CASE WHEN v_q_ord.q_gr Is Not Null THEN v_q_ord.q_gr_pref ELSE v_q.q_gr_pref END AS q_gr_pref_sel, 
	CASE WHEN v_q_ord.q_gr Is Not Null THEN v_q_ord.q_gr_type ELSE v_q.q_gr_type END AS q_gr_type_sel, 
	v_q.q_supp_abs_order_pos AS q_pos_supp, 
	v_soil_q.order_pos AS q_pos_inc 
FROM ((((v_soil_q LEFT JOIN v_s ON v_soil_q.sid = v_s.sid) INNER JOIN v_soil_prof ON v_soil_q.profid = v_soil_prof.profid) INNER JOIN v_q_ord ON (v_soil_q.qid = v_q_ord.qid) AND (v_soil_prof.rid = v_q_ord.rid) AND CASE WHEN v_q_ord.sid IS NOT NULL THEN (v_soil_q.sid = v_q_ord.sid) ELSE TRUE END) INNER JOIN v_q ON v_q_ord.qid = v_q.qid) INNER JOIN v_q AS v_q_1 ON v_q.q_rel = v_q_1.qid 
WHERE 
	(v_q.q_gr_type <> 4 OR v_q.q_gr_type Is Null OR (v_soil_q.sid IN (3,10,11))) AND 
	((((v_q_ord.q_role<60) OR (v_soil_q.sid IN (3,11)) OR (v_soil_q.sid Is Not NULL AND (COALESCE (v_q_ord.q_gr,v_q.q_gr,v_q.q_mgr)) IS NULL)) AND (((((v_soil_q.sid)=1) AND (v_q.amphi=True)) OR (((v_soil_q.sid)=2) AND ((v_q.ano)=True)) OR (((v_soil_q.sid)=3) AND ((v_q.bathy)=True)) OR (((v_soil_q.sid)=4) AND ((v_q.endo)=True)) OR (((v_soil_q.sid)=5) AND ((v_q.epi)=True)) OR (((v_soil_q.sid)=6) AND ((v_q.kato)=True)) OR (((v_soil_q.sid)=7) AND ((v_q.panto)=True)) OR (((v_soil_q.sid)=8) AND ((v_q.poly)=True)) OR (((v_soil_q.sid)=9) AND ((v_q.supra)=True)) OR (((v_soil_q.sid IN (10,11)) AND ((v_q.thapto)=True)))))))  
ORDER BY v_soil_q.profid, v_q_ord.qid) 
UNION (SELECT 
	v_soil_q.profid, 
    v_q.qid,
    v_q.q AS q_corr,
    v_q.q_abbr AS q_abbr_corr,
    v_s.sid, 
	v_s.s,
    v_q.q, 
	CASE WHEN v_q_ord.q_pos Is Null AND v_q_ord.q_role>=40 THEN (20000+3*v_q.q_supp_abs_order_pos+v_s.sid-3) 
		WHEN v_q_ord.q_pos Is Null THEN v_q.q_supp_abs_order_pos 
		WHEN v_soil_q.sid=3 Or v_soil_q.sid=10 THEN v_q.q_supp_abs_order_pos 
		ELSE v_q_ord.q_pos END AS q_pos, 
    v_q_ord.q_role,
    COALESCE (v_q_ord.q_gr,v_q.q_gr,v_q.q_mgr) AS q_gr_sel, 
	CASE WHEN v_q_ord.q_gr Is Not Null THEN v_q_ord.q_gr_pref ELSE CASE WHEN v_q.q_gr_pref IS NULL THEN 1::int ELSE v_q.q_gr_pref END  END AS q_gr_pref_sel, 
	CASE WHEN v_q_ord.q_gr Is Not Null THEN v_q_ord.q_gr_type ELSE v_q.q_gr_type END AS q_gr_type_sel,
    v_q.q_supp_abs_order_pos AS q_pos_supp, 
	v_soil_q.order_pos AS q_pos_inc 
FROM (((v_soil_q LEFT JOIN v_s ON v_soil_q.sid = v_s.sid) INNER JOIN v_soil_prof ON v_soil_q.profid = v_soil_prof.profid) INNER JOIN v_q_ord ON (v_soil_q.qid = v_q_ord.qid) AND (v_soil_prof.rid = v_q_ord.rid)) INNER JOIN v_q ON v_q_ord.qid = v_q.qid
WHERE (v_q.q_gr_type Is NULL OR v_q.q_gr_type <> 4) AND ((v_q_ord.q_role<60 OR v_q_ord.q_role IS NULL) AND (((v_soil_q.sid IS NULL) OR ((v_soil_q.sid = 1) AND ((v_q.amphi = false) OR (v_q.amphi IS NULL))) OR ((v_soil_q.sid = 2) AND ((v_q.ano = false) OR (v_q.ano IS NULL))) OR ((v_soil_q.sid = 4) AND ((v_q.endo = false) OR (v_q.endo IS NULL))) OR ((v_soil_q.sid = 5) AND ((v_q.epi = false) OR (v_q.epi IS NULL))) OR ((v_soil_q.sid = 6) AND ((v_q.kato = false) OR (v_q.kato IS NULL))) OR ((v_soil_q.sid = 7) AND ((v_q.panto = false) OR (v_q.panto IS NULL))) OR ((v_soil_q.sid = 8) AND ((v_q.poly = false) OR (v_q.poly IS NULL))) OR ((v_soil_q.sid = 9) AND ((v_q.supra = false) OR (v_q.supra IS NULL))) OR ((v_soil_q.sid = 10) AND ((v_q.thapto = false) OR (v_q.thapto IS NULL)))))) 
ORDER BY v_soil_q.profid, v_q_ord.qid);

-- v_soil_q_corr_add provides those (sub)qualifiers that in principle can also be added when other subqualifiers of the same qualifier apply or that can only be added if other (sub)qualifiers also apply (these are identified using the group numbers and (negative) group preference numbers from v_q_ord)
CREATE VIEW v_soil_q_corr_add AS 
(SELECT DISTINCT 
	v_soil_q.profid, 
	v_q_ord.qid, 
	CASE WHEN v_q.q_prefix Is NULL THEN v_s.s::text||LOWER(v_q.q)::text ELSE v_q.q_prefix||v_s.s::text||LOWER(v_q.q)::text END AS q_corr, 
	v_q.q_abbr::text||v_s.s_abbr::text AS q_abbr_corr, 
	v_soil_q.sid, 
	v_s.s, v_q.q, 
	CASE WHEN (v_q_ord.q_pos Is Null AND v_q_ord.q_role>=40) THEN (20000+3*v_q.q_supp_abs_order_pos+v_s.sid-3) WHEN v_q_ord.q_pos Is Null THEN v_q.q_supp_abs_order_pos WHEN (v_soil_q.sid=3 Or v_soil_q.sid=10) THEN v_q.q_supp_abs_order_pos ELSE v_q_ord.q_pos END AS q_pos, 
	v_q_ord.q_role, 
	COALESCE (v_q_ord.q_gr, v_q.q_gr) AS q_gr_sel, 
	CASE WHEN v_q_ord.q_gr Is Not Null THEN v_q_ord.q_gr_pref ELSE v_q.q_gr_pref END AS q_gr_pref_sel, 
	CASE WHEN v_q_ord.q_gr Is Not Null THEN v_q_ord.q_gr_type ELSE v_q.q_gr_type END AS q_gr_type_sel, 
	v_q.q_supp_abs_order_pos AS q_pos_supp, 
	v_q_ord.q_gr_pref_cond
FROM ((((v_soil_q LEFT JOIN v_s ON v_soil_q.sid = v_s.sid) INNER JOIN v_soil_prof ON v_soil_q.profid = v_soil_prof.profid) INNER JOIN v_q_ord ON (v_soil_q.qid = v_q_ord.qid) AND (v_soil_prof.rid = v_q_ord.rid)) INNER JOIN v_q ON v_q_ord.qid = v_q.qid) INNER JOIN v_q AS v_q_1 ON v_q.q_rel = v_q_1.qid 
WHERE ((v_q_ord.q_role)<60 Or (v_q_ord.q_role) Is Null) AND 
	((CASE WHEN v_q_ord.q_gr Is Not Null THEN v_q_ord.q_gr_pref ELSE v_q.q_gr_pref END) Is Not Null And (CASE WHEN v_q_ord.q_gr Is Not Null THEN v_q_ord.q_gr_pref ELSE v_q.q_gr_pref END)<0) AND 
	(((v_soil_q.sid=1) AND (v_q.amphi=true)) 
		OR ((v_soil_q.sid=2) AND (v_q.ano=true))
		OR ((v_soil_q.sid=3) AND (v_q.bathy=true)) 
		OR ((v_soil_q.sid=4) AND (v_q.endo=true)) 
		OR ((v_soil_q.sid=5) AND (v_q.epi=true)) 
		OR ((v_soil_q.sid=6) AND (v_q.kato=true)) 
		OR ((v_soil_q.sid=7) AND (v_q.panto=true)) 
		OR ((v_soil_q.sid=8) AND (v_q.poly=true)) 
		OR ((v_soil_q.sid=9) AND (v_q.supra=true)) 
		OR ((v_soil_q.sid=10) AND (v_q.thapto=true))) 
ORDER BY v_soil_q.profid, v_q_ord.qid) 
UNION (SELECT 
	v_soil_q.profid,
    v_q.qid,
    v_q.q AS q_corr,
    v_q.q_abbr AS q_abbr_corr,
    v_soil_q.sid,
    v_s.s,
    v_q.q, 
    COALESCE (v_q_ord.q_pos, v_q.q_supp_abs_order_pos) AS q_pos, 
    v_q_ord.q_role,
    COALESCE (v_q_ord.q_gr, v_q.q_gr) AS q_gr_sel, 
	CASE WHEN v_q_ord.q_gr Is Not Null THEN v_q_ord.q_gr_pref ELSE v_q.q_gr_pref END AS q_gr_pref_sel, 
	CASE WHEN v_q_ord.q_gr Is Not Null THEN v_q_ord.q_gr_type ELSE v_q.q_gr_type END AS q_gr_type_sel,
    v_q.q_supp_abs_order_pos AS q_pos_supp, 
	v_q_ord.q_gr_pref_cond 
FROM (((v_soil_q LEFT JOIN v_s ON v_soil_q.sid = v_s.sid) INNER JOIN v_soil_prof ON v_soil_q.profid = v_soil_prof.profid) INNER JOIN v_q_ord ON (v_soil_q.qid = v_q_ord.qid) AND (v_soil_prof.rid = v_q_ord.rid)) INNER JOIN v_q ON v_q_ord.qid = v_q.qid 
WHERE (CASE WHEN v_q_ord.q_gr Is Not Null THEN v_q_ord.q_gr_pref ELSE v_q.q_gr_pref END) Is NOT NULL AND 
	(CASE WHEN v_q_ord.q_gr Is Not Null THEN v_q_ord.q_gr_pref ELSE v_q.q_gr_pref END)<0 AND 
	((((v_soil_q.sid IS NULL) OR ((v_soil_q.sid = 1) AND ((v_q.amphi = false) OR (v_q.amphi IS NULL))) OR ((v_soil_q.sid = 2) AND ((v_q.ano = false) OR (v_q.ano IS NULL))) OR ((v_soil_q.sid = 3) AND ((v_q.bathy = false) OR (v_q.bathy IS NULL))) OR ((v_soil_q.sid = 4) AND ((v_q.endo = false) OR (v_q.endo IS NULL))) OR ((v_soil_q.sid = 5) AND ((v_q.epi = false) OR (v_q.epi IS NULL))) OR ((v_soil_q.sid = 6) AND ((v_q.kato = false) OR (v_q.kato IS NULL))) OR ((v_soil_q.sid = 7) AND ((v_q.panto = false) OR (v_q.panto IS NULL))) OR ((v_soil_q.sid = 8) AND ((v_q.poly = false) OR (v_q.poly IS NULL))) OR ((v_soil_q.sid = 9) AND ((v_q.supra = false) OR (v_q.supra IS NULL))) OR ((v_soil_q.sid = 10) AND ((v_q.thapto = false) OR (v_q.thapto IS NULL))) OR ((v_soil_q.sid = 11) AND ((v_q.bathy = false) OR (v_q.thapto = false) OR (v_q.thapto IS NULL) OR (v_q.bathy IS NULL)))) AND (v_q_ord.q_role<60 OR v_q_ord.q_role IS NULL)))
ORDER BY v_soil_q.profid, v_q_ord.qid);

-- v_soil_q_corr_sel_add filters v_soil_q_corr_add for applicable (sub)qualifiers which in turn can only be applied if other (sub)qualifiers apply as well to the soil profile
-- and combines the result with the valid texture (sub)qualifiers from v_soil_txq_corr_sel
CREATE VIEW v_soil_q_corr_sel_add AS 
(SELECT v_soil_q_corr_add.profid, 
	v_soil_q_corr_add.qid, 
	v_soil_q_corr_add.q_corr, 
	v_soil_q_corr_add.q_abbr_corr, 
	v_soil_q_corr_add.sid, 
	v_soil_q_corr_add.s, 
	v_soil_q_corr_add.q, 
	v_soil_q_corr_add.q_pos, 
	v_soil_q_corr_add.q_role, 
	v_soil_q_corr_add.q_gr_sel, 
	CASE WHEN (v_soil_q_corr_add.q_gr_pref_sel < v_soil_q_corr_indep.q_gr_pref_sel) THEN ((v_soil_q_corr_add.q_gr_pref_sel)*-1) ELSE v_soil_q_corr_indep.q_gr_pref_sel END AS q_gr_pref_sel, 
	v_soil_q_corr_add.q_gr_type_sel, 
	v_soil_q_corr_add.q_pos_supp
FROM v_soil_q_corr_indep LEFT JOIN v_soil_q_corr_add ON (v_soil_q_corr_indep.profid = v_soil_q_corr_add.profid) AND (v_soil_q_corr_indep.q_gr_sel = v_soil_q_corr_add.q_gr_sel) 
WHERE (((v_soil_q_corr_add.profid) Is Not Null) AND ((v_soil_q_corr_indep.sid) In (1,4,6))) OR 
	(((v_soil_q_corr_add.profid) Is Not Null) AND ((v_soil_q_corr_add.q_gr_type_sel)=5))) 
UNION (SELECT v_soil_txq_corr_sel.profid, 
	v_soil_txq_corr_sel.qid, 
	v_soil_txq_corr_sel.q_corr, 
	v_soil_txq_corr_sel.q_abbr_corr, 
	v_soil_txq_corr_sel.sid, 
	v_soil_txq_corr_sel.s, 
	v_soil_txq_corr_sel.q, 
	v_soil_txq_corr_sel.q_pos, 
	v_soil_txq_corr_sel.q_role, 
	v_soil_txq_corr_sel.q_gr_sel, 
	v_soil_txq_corr_sel.q_gr_pref_sel, 
	v_soil_txq_corr_sel.q_gr_type_sel, 
	v_soil_txq_corr_sel.q_pos_supp
FROM v_soil_txq_corr_sel);

-- v_soil_q_corr_sel_prep combines the corrected (sub)qualifiers of v_soil_q_corr_indep and v_soil_q_corr_sel_add
CREATE VIEW v_soil_q_corr_sel_prep AS 
(SELECT v_soil_q_corr_indep.profid, 
	v_soil_q_corr_indep.qid, 
	v_soil_q_corr_indep.q_corr, 
	v_soil_q_corr_indep.q_abbr_corr, 
	v_soil_q_corr_indep.sid, 
	v_soil_q_corr_indep.s, 
	v_soil_q_corr_indep.q, 
	v_soil_q_corr_indep.q_pos, 
	v_soil_q_corr_indep.q_role, 
	v_soil_q_corr_indep.q_gr_sel, 
	v_soil_q_corr_indep.q_gr_pref_sel, 
	v_soil_q_corr_indep.q_gr_type_sel, 
	v_soil_q_corr_indep.q_pos_supp, 
	v_soil_q_corr_indep.q_pos_inc 
FROM v_soil_q_corr_indep) 
UNION (SELECT v_soil_q_corr_sel_add.profid, 
	v_soil_q_corr_sel_add.qid, 
	v_soil_q_corr_sel_add.q_corr, 
	v_soil_q_corr_sel_add.q_abbr_corr, 
	v_soil_q_corr_sel_add.sid, 
	v_soil_q_corr_sel_add.s, 
	v_soil_q_corr_sel_add.q, 
	v_soil_q_corr_sel_add.q_pos, 
	v_soil_q_corr_sel_add.q_role, 
	v_soil_q_corr_sel_add.q_gr_sel, 
	v_soil_q_corr_sel_add.q_gr_pref_sel, 
	v_soil_q_corr_sel_add.q_gr_type_sel, 
	v_soil_q_corr_sel_add.q_pos_supp, 
	0::int AS q_pos_inc 
FROM v_soil_q_corr_sel_add);

-- v_soil_q_gr_sel provides the group numbers of (sub)qualifiers from which qualifiers have been applied
CREATE VIEW v_soil_q_gr_sel AS 
SELECT v_soil_q_corr_indep.profid, 
	v_soil_q_corr_indep.q_gr_sel, 
	Min(v_soil_q_corr_indep.q_gr_pref_sel) AS min_q_gr_pref_sel, 
	Min(v_soil_q_corr_indep.q_pos) AS min_q_pos_gr, 
	CASE WHEN (MIN(v_soil_q_corr_indep.q_pos)<1000 AND Max(v_soil_q_corr_indep.q_pos)>=1000) 
		THEN MIN(v_soil_q_corr_indep.q_pos) 
		ELSE Max(v_soil_q_corr_indep.q_pos) END AS max_q_pos_gr 
FROM v_soil_q_corr_indep JOIN v_soil_prof ON (v_soil_q_corr_indep.profid=v_soil_prof.profid) JOIN v_q_ord ON (v_soil_prof.rid=v_q_ord.rid AND v_soil_q_corr_indep.qid=v_q_ord.qid) 
-- exclude all groups with q_gr_type 2 'with differing specifiers possible', applies to Dystric/Eutric/etc. and Fibric/Hemic/Sapric groups
--WHERE v_soil_q_corr_indep.profid BETWEEN 503 AND 505 
GROUP BY v_soil_q_corr_indep.profid, v_soil_q_corr_indep.q_gr_sel
HAVING MIN(v_q_ord.q_gr_type) <> 2 or (MIN(v_q_ord.q_gr_type)=2 AND MAX(v_soil_q_corr_indep.sid)=Null)
ORDER BY profid;

-- v_soil_q_corr_sel_prep2 filters v_soil_q_corr_sel_prep (sub)qualifiers for those additional (sub)qualifiers whose group number and group preference number equals 
--		that identified in v_soil_q_gr_sel; which means they do apply
CREATE VIEW v_soil_q_corr_sel_prep2 AS 
(SELECT v_soil_q_corr_sel_prep.profid, 
	v_soil_q_corr_sel_prep.qid, 
	v_soil_q_corr_sel_prep.q_corr, 
	v_soil_q_corr_sel_prep.q_abbr_corr, 
	v_soil_q_corr_sel_prep.sid, 
	v_soil_q_corr_sel_prep.s, 
	v_soil_q_corr_sel_prep.q, 
	v_soil_q_corr_sel_prep.q_pos, 
	CASE WHEN (v_soil_q_corr_sel_prep.q_gr_type_sel=2 AND (v_soil_q_corr_sel_prep.sid IN (3,10,11))) THEN v_soil_q_corr_sel_prep.q_pos_supp 
-- sorting Fibric/Hemic/Sapric depth-related subqualifiers as inexlicitly defined always in this order (following line active, next2 lines inactive:):		
--	WHEN (v_soil_q_corr_sel_prep.q_gr_type_sel=2 Or v_soil_q_corr_sel_prep.q_gr_type_sel=4) THEN Min_q_pos_gr+CASE WHEN v_soil_q_corr_sel_prep.sid Is Not Null THEN v_soil_q_corr_sel_prep.sid ELSE 0 END 
-- sorting Fibric/Hemic/Sapric depth-related subqualifiers from top to bottom of the soil profile so that top is nearest to the RSG name (see column s_pos_inc of ct_s); specifier meaning overrides the explicit order_pos as given by the user. (following 2 lines active, foregoing line inactive):
		WHEN v_soil_q_corr_sel_prep.q_gr_type_sel=2 THEN 130+(CASE WHEN v_soil_q_corr_sel_prep.sid Is Not Null THEN (CASE v_soil_q_corr_sel_prep.sid WHEN 2 THEN 1 WHEN 5 THEN 2 WHEN 8 THEN 3 WHEN 1 THEN 4 WHEN 6 THEN 5 WHEN 4 THEN 6 ELSE 0 END) ELSE v_soil_q_corr_sel_prep.q_pos_inc END) 
		WHEN v_soil_q_corr_sel_prep.q_gr_type_sel=4 THEN Min_q_pos_gr+CASE WHEN v_soil_q_corr_sel_prep.sid Is Not Null THEN v_soil_q_corr_sel_prep.sid ELSE 0 END 
		ELSE COALESCE(v_soil_q_corr_sel_prep.q_pos, v_soil_q_corr_sel_prep.q_pos_supp) END AS q_pos_corr, 
	v_soil_q_corr_sel_prep.q_role, 
	v_soil_q_corr_sel_prep.q_gr_sel, 
	v_soil_q_corr_sel_prep.q_gr_pref_sel, 
	v_soil_q_corr_sel_prep.q_gr_type_sel, 
	v_soil_q_corr_sel_prep.q_pos_supp, 
	v_soil_q_gr_sel.min_q_gr_pref_sel, 
	v_soil_q_gr_sel.min_q_pos_gr, 
	v_soil_q_gr_sel.max_q_pos_gr 
FROM v_soil_q_corr_sel_prep LEFT JOIN v_soil_q_gr_sel ON (v_soil_q_corr_sel_prep.profid = v_soil_q_gr_sel.profid) AND (v_soil_q_corr_sel_prep.q_gr_sel = v_soil_q_gr_sel.q_gr_sel) 
WHERE 
((((v_soil_q_corr_sel_prep.q_gr_pref_sel=Min_q_gr_pref_sel) AND ((v_soil_q_corr_sel_prep.q_gr_pref_sel > 0) OR (v_soil_q_corr_sel_prep.sid Is Not Null))) AND 
	(((v_soil_q_corr_sel_prep.q_gr_type_sel) IN (1,3,5)))) OR 
	((v_soil_q_corr_sel_prep.q_gr_pref_sel=-1*Min_q_gr_pref_sel) AND v_soil_q_corr_sel_prep.q_gr_pref_sel > 0) OR
	((v_soil_q_corr_sel_prep.q_gr_type_sel Is Null OR (v_soil_q_corr_sel_prep.q_gr_sel) Is Null))) OR
	v_soil_q_corr_sel_prep.q_gr_type_sel Is Null OR 
	v_soil_q_corr_sel_prep.q_gr_type_sel = 2 
ORDER BY v_soil_q_corr_sel_prep.profid) 
UNION (SELECT q3.profid, 
	MIN(q3.qid) AS qid, 
	MIN(v_s.s)||Lower(MIN(v_q.q)) AS q_corr, 
	MIN(v_q.q_abbr)||MIN(v_s.s_abbr) AS q_abbr_corr, 
	q3.sid, 
	MIN(v_s.s) AS s, 
	q3.q, 
	NULL::int AS q_pos, 
	(CASE WHEN (MIN(q3.q_pos)<1000 AND Max(q3.q_pos)>=1000) 
		THEN MIN(q3.q_pos) 
		ELSE Max(q3.q_pos) END) - 2*q3.sid + 9 AS q_pos_corr, 
	Min(q3.q_role) AS q_role, 
	MIN(q3.q_gr_sel3) AS q_gr_sel, 
	Min(q3.q_gr_pref_sel) AS q_gr_pref_sel, 
	Min(q3.q_gr_type_sel) AS q_gr_type_sel, 
	(CASE WHEN (MIN(q3.q_pos)<1000 AND Max(q3.q_pos)>=1000) 
		THEN MIN(q3.q_pos) 
		ELSE Max(q3.q_pos) END) AS q_pos_supp, 
	Min(q3.q_gr_pref_sel) AS min_q_gr_pref_sel, 
	(CASE WHEN (MIN(q3.q_pos)<1000 AND Max(q3.q_pos)>=1000) 
		THEN MIN(q3.q_pos) 
		ELSE Max(q3.q_pos) END) - 2*q3.sid + 9 AS min_q_pos_gr, 
	(CASE WHEN (MIN(q3.q_pos)<1000 AND Max(q3.q_pos)>=1000) 
		THEN MIN(q3.q_pos) 
		ELSE Max(q3.q_pos) END) - 2*q3.sid + 9 AS max_q_pos_gr 
FROM (v_soil_q_corr_indep RIGHT JOIN 
		(SELECT v_soil_q_corr_indep.profid AS profid3, 
				Min(v_soil_q_corr_indep.qid) AS mqid, 
		 		v_soil_q_corr_indep.q_gr_sel AS q_gr_sel3,  
				v_q.q_s_rule, 
				Min(v_soil_q_corr_indep.q_pos) AS min_q_pos_gr, 
				CASE WHEN (MIN(v_soil_q_corr_indep.q_pos)<1000 AND Max(v_soil_q_corr_indep.q_pos)>=1000) 
					THEN MIN(v_soil_q_corr_indep.q_pos) 
					ELSE Max(v_soil_q_corr_indep.q_pos) END AS max_q_pos_gr,
		 		v_soil_q_corr_indep.q_gr_sel AS q_gr_sel1 
			FROM v_soil_q_corr_indep LEFT JOIN v_q ON (v_soil_q_corr_indep.qid = v_q.qid) 
			WHERE v_q.q_s_rule = 3 AND v_soil_q_corr_indep.sid IS NULL 
			GROUP BY v_soil_q_corr_indep.profid, v_soil_q_corr_indep.q_gr_sel, v_q.q_s_rule 
			HAVING Count(v_q.q_s_rule)=1) 
	AS q2 ON (v_soil_q_corr_indep.profid = q2.profid3)) AS q3 LEFT JOIN v_q ON (q3.qid=v_q.qid) LEFT JOIN v_s ON (q3.sid=v_s.sid)  
WHERE q3.profid IS NOT NULL AND q3.mqid<>q3.qid AND q3.sid IS NOT NULL 
GROUP BY q3.profid, q3.q, q3.s, q3.q_gr_sel1, q3.sid 
HAVING count(q3.sid) < 2);


-- The qualifiers related to peat decomposition (Fibric, Hemic, Sapric) are mutually exclusive within the same depth range, but can apply together; the rules are similar to those of the texture-related qualifiers
-- 3a) When one qualifier has the Panto- specifier, no other qualifier can be assigned, except if combined with Bathy- or Thaptobathy-;
--		and when a qualifier has the Ano- or Kato- specifier, respectively, can there only be - except if combined with Bathy- or Thaptobathy- - one other qualifier with the Endo- or Poly- specifier, or with the Epi- or Poly- specifier, respectively
-- This view contains all profiles that have errors in this respect 
CREATE VIEW v_soil_q_corr_sel_prep3a AS 
((SELECT v.profid, v_soil_q.qid, v_soil_q.sid 
FROM (SELECT DISTINCT v_soil_q.qid AS qid, v_soil_q.sid AS sid, v_soil_q.profid AS profid FROM v_soil_q INNER JOIN v_q ON (v_soil_q.qid=v_q.qid) WHERE v_q.qid IN (2190,3150,8190) AND v_soil_q.sid=7) AS v INNER JOIN v_soil_q ON (v.profid=v_soil_q.profid)   
WHERE v_soil_q.sid NOT IN (3,7,10,11) OR v_soil_q.sid IS NULL) 
UNION (SELECT v.profid, v_soil_q.qid, v_soil_q.sid 
FROM (SELECT DISTINCT v_soil_q.qid AS qid, v_soil_q.sid AS sid, v_soil_q.profid AS profid FROM v_soil_q INNER JOIN v_q ON (v_soil_q.qid=v_q.qid) WHERE  v_q.qid IN (2190,3150,8190) AND v_soil_q.sid=2) AS v INNER JOIN v_soil_q ON (v.profid=v_soil_q.profid) 
WHERE v_soil_q.sid NOT IN (2,3,4,6,7,8,10,11)) 
UNION (SELECT v.profid, v_soil_q.qid, v_soil_q.sid 
FROM (SELECT DISTINCT v_soil_q.qid AS qid, v_soil_q.sid AS sid, v_soil_q.profid AS profid FROM v_soil_q INNER JOIN v_q ON (v_soil_q.qid=v_q.qid) WHERE  v_q.qid IN (2190,3150,8190) AND v_soil_q.sid=6) AS v INNER JOIN v_soil_q ON (v.profid=v_soil_q.profid)   
WHERE v_soil_q.sid NOT IN (2,3,5,6,7,8,10,11)))
UNION (SELECT v_soil_q.profid, NULL AS qid, v_soil_q.sid 
FROM v_soil_q 
WHERE qid IN (2190,3150,8190) AND sid IN (1,2,4,5,6,7,8) GROUP BY profid, sid HAVING COUNT(sid)>1);

-- 3. b) If three qualifiers (except those combined with Bathy-, Thaptobathy-) are assigned, they must be used without specifier or with once each of Epi-, Amphi- or Endo-, or with the Poly- specifier;
--		and not more than three (sub-)qualifiers (except those combined with Bathy-, Thaptobathy-) can be assigned
-- This view contains all profiles that have errors in this respect
CREATE VIEW v_soil_q_corr_sel_prep3b AS 
((SELECT v_soil_q.profid 
FROM v_soil_q INNER JOIN v_q ON (v_soil_q.qid=v_q.qid) 
WHERE  v_q.qid IN (2190,3150,8190) AND (v_soil_q.sid NOT IN (3,10,11) OR v_soil_q.sid IS NULL) 
GROUP BY v_soil_q.profid 
HAVING COUNT(v_soil_q.qid)>3) 
UNION (SELECT v_soil_q.profid 
FROM (SELECT v_soil_q.profid FROM v_soil_q INNER JOIN v_q ON (v_soil_q.qid=v_q.qid) WHERE  v_q.qid IN (2190,3150,8190) AND (v_soil_q.sid NOT IN (3,10,11) OR v_soil_q.sid IS NULL) GROUP BY v_soil_q.profid HAVING COUNT(v_soil_q.qid)>=3) AS v LEFT JOIN v_soil_q ON (v.profid=v_soil_q.profid) LEFT JOIN v_q ON (v_soil_q.qid=v_q.qid) 
WHERE (v_soil_q.sid NOT IN (1,3,4,5,8,10) AND v_soil_q.sid IS NOT NULL) 
ORDER BY v_soil_q.profid));

-- The qualifiers Dystric and Eutric can only be used both when one of them is used with the specifier Endo or Epi
-- v_soil_q_corr_sel_prep4 contains all profiles that have errors in this respect
CREATE VIEW v_soil_q_corr_sel_prep4 AS
(SELECT v_soil_q.profid 
FROM v_soil_q 
WHERE v_soil_q.qid IN (1620, 1860, 1890) 
GROUP BY v_soil_q.profid 
HAVING Count(v_soil_q.qid)=2 AND Count(v_soil_q.sid)<>1);

-- v_soil_q_corr_sel holds the final list of applicable (sub)qualifiers (which is the corrected list of all (sub)qualifiers applied by the DB user to the soil profiles); in the following, this final list is further processed for principal and supplementary (sub)qualifiers separately
CREATE MATERIALIZED VIEW v_soil_q_corr_sel AS
(
	SELECT DISTINCT ON (v_soil_q_corr_sel_prep2.profid, v_soil_q_corr_sel_prep2.qid, v_soil_q_corr_sel_prep2.sid) 
	v_soil_q_corr_sel_prep2.profid, 
	v_soil_q_corr_sel_prep2.qid, 
	v_soil_q_corr_sel_prep2.q_corr, 
	v_soil_q_corr_sel_prep2.q_abbr_corr, 
	v_soil_q_corr_sel_prep2.sid, 
	v_soil_q_corr_sel_prep2.s, 
	v_soil_q_corr_sel_prep2.q, 
	CASE WHEN v_soil_q_corr_sel_prep2.q_role=40 THEN 20000+3*COALESCE(v_soil_q_corr_sel_prep2.q_pos, v_soil_q_corr_sel_prep2.q_pos_corr) ELSE COALESCE(v_soil_q_corr_sel_prep2.q_pos, v_soil_q_corr_sel_prep2.q_pos_corr) END AS q_pos,  
	v_soil_q_corr_sel_prep2.q_role, 
	v_soil_q_corr_sel_prep2.q_gr_sel, 
	v_soil_q_corr_sel_prep2.q_gr_pref_sel, 
	v_soil_q_corr_sel_prep2.q_gr_type_sel, 
	v_soil_q_corr_sel_prep2.q_pos_supp, 
--	(CASE WHEN (v_soil_q_corr_sel_prep2.q_gr_type_sel=2 AND ((v_soil_q_corr_sel_prep2.sid IN (3,10,11)) OR v_soil_q_corr_sel_prep2.sid=8)) 
	(CASE WHEN (v_soil_q_corr_sel_prep2.q_gr_type_sel=2 AND v_soil_q_corr_sel_prep2.sid IN (3,8,10,11)) 
		THEN (
			CASE WHEN (v_soil_q_corr_sel_prep2.sid IN (3,10,11)) THEN v_soil_q_corr_sel_prep2.q_pos_supp ELSE v_soil_q_corr_sel_prep2.q_pos END
				+(
					(CASE WHEN (v_soil_q_corr_sel_prep2.q_pos<1000 AND v_soil_q_corr_sel_prep2.qid NOT IN (1620, 1860)) THEN -1 ELSE 1 END) *
					(CASE WHEN v_soil_q_corr_sel_prep2.sid Is Not Null THEN v_soil_q_corr_sel_prep2.sid ELSE 0 END))) 
		ELSE (CASE WHEN v_soil_q_corr_sel_prep2.q_gr_type_sel=2 AND v_soil_q_corr_sel_prep2.q_pos < 1000 
			THEN v_soil_q_corr_sel_prep2.q_pos_corr 
			ELSE v_soil_q_corr_sel_prep2.q_pos 
		END) END) AS q_pos_corr 
FROM ((v_soil_q_corr_sel_prep2 LEFT JOIN v_soil_q_corr_sel_prep3a ON v_soil_q_corr_sel_prep2.profid=v_soil_q_corr_sel_prep3a.profid) 
	LEFT JOIN v_soil_q_corr_sel_prep3b ON v_soil_q_corr_sel_prep2.profid=v_soil_q_corr_sel_prep3a.profid) 
	LEFT JOIN v_soil_q_corr_sel_prep4 ON v_soil_q_corr_sel_prep2.profid=v_soil_q_corr_sel_prep4.profid 
WHERE (v_soil_q_corr_sel_prep2.q_gr_type_sel IS Null OR v_soil_q_corr_sel_prep2.q_gr_type_sel<>4) AND 
	v_soil_q_corr_sel_prep3a.profid IS NULL AND 
	v_soil_q_corr_sel_prep3b.profid IS NULL AND 
	(v_soil_q_corr_sel_prep4.profid IS NULL OR v_soil_q_corr_sel_prep2.qid NOT IN (1620, 1860, 1890)) 
	--AND ((v_soil_q_corr_sel_prep2.q_gr_pref_sel < 0 AND v_soil_q_corr_sel_prep2.q_gr_type_sel = 5) OR v_soil_q_corr_sel_prep2.q_gr_pref_sel IS NULL OR v_soil_q_corr_sel_prep2.q_gr_pref_sel > 0) 
ORDER BY v_soil_q_corr_sel_prep2.profid, v_soil_q_corr_sel_prep2.qid, v_soil_q_corr_sel_prep2.sid
) 
UNION 
(
SELECT 
	v_soil_txq_corr_sel.profid, 
	v_soil_txq_corr_sel.qid, 
	v_soil_txq_corr_sel.q_corr, 
	v_soil_txq_corr_sel.q_abbr_corr, 
	v_soil_txq_corr_sel.sid, 
	v_soil_txq_corr_sel.s, 
	v_soil_txq_corr_sel.q, v_soil_txq_corr_sel.q_pos, 
	v_soil_txq_corr_sel.q_role, 
	v_soil_txq_corr_sel.q_gr_sel, 
	v_soil_txq_corr_sel.q_gr_pref_sel, 
	v_soil_txq_corr_sel.q_gr_type_sel, 
	v_soil_txq_corr_sel.q_pos_supp, 
	MIN(v_soil_txq_corr_sel.q_pos) AS q_pos  
FROM v_soil_txq_corr_sel 
GROUP BY v_soil_txq_corr_sel.profid, v_soil_txq_corr_sel.qid, v_soil_txq_corr_sel.sid, v_soil_txq_corr_sel.q_corr, v_soil_txq_corr_sel.q_abbr_corr, v_soil_txq_corr_sel.s, v_soil_txq_corr_sel.q, v_soil_txq_corr_sel.q_pos, v_soil_txq_corr_sel.q_role, 
	v_soil_txq_corr_sel.q_gr_sel, v_soil_txq_corr_sel.q_gr_pref_sel, v_soil_txq_corr_sel.q_gr_type_sel, v_soil_txq_corr_sel.q_pos_supp
);

CREATE UNIQUE INDEX UniqueIndex_v_soil_q_corr_sel ON v_soil_q_corr_sel (profid, qid, sid);

REFRESH MATERIALIZED VIEW CONCURRENTLY v_soil_q_corr_sel WITH DATA;

-- SUPPLEMENTARY (sub)qualifier handling
-- v_soil_q_supp_prep filters v_soil_q_corr_sel for supplementary qualifiers
CREATE VIEW v_soil_q_supp_prep AS 
(SELECT v_soil_q_corr_sel.profid, 
	v_soil_q_corr_sel.q_corr, 
	v_soil_q_corr_sel.q_abbr_corr, 
	COALESCE (v_soil_q_corr_sel.q_pos_corr, v_soil_q_corr_sel.q_pos) AS q_pos, 
	v_soil_q_corr_sel.sid, 
	v_q_ord.q_role,
	CASE WHEN v_soil_q_corr_sel.sid<=8 THEN 1 ELSE (CASE WHEN v_soil_q_corr_sel.sid Is Null THEN 0 ELSE v_soil_q_corr_sel.sid END) END As sidCheck 
FROM (v_soil_q_corr_sel 
	INNER JOIN (v_soil_prof 
	INNER JOIN v_q_ord ON v_soil_prof.rid=v_q_ord.rid) ON (v_soil_q_corr_sel.profid=v_soil_prof.profid) AND (v_soil_q_corr_sel.qid=v_q_ord.qid)) 
	LEFT JOIN v_s ON v_soil_q_corr_sel.sid=v_s.sid 
WHERE COALESCE (v_soil_q_corr_sel.q_pos_corr, 
	v_soil_q_corr_sel.q_pos) > 1000 AND ((v_q_ord.q_role<45) OR ((v_soil_q_corr_sel.sid=v_q_ord.sid) AND (v_q_ord.q_role=45)) OR (v_soil_q_corr_sel.q_role>=60 AND v_soil_q_corr_sel.sid IN (3,11))) 
ORDER BY v_soil_prof.profid, 
	CASE WHEN v_q_ord.q_pos Is Not Null THEN v_q_ord.q_pos ELSE (CASE WHEN v_q_ord.q_role=30 THEN s_tx_pos ELSE v_soil_q_corr_sel.q_pos_corr END) END);
	
-- v_soil_prof_q_cond_gr_pres provides for each soil profile the groups of conditionally mandatory qualifiers for which a qualifier has been selected
CREATE VIEW v_soil_prof_q_cond_gr_pres AS 
SELECT DISTINCT v_soil_prof.profid, 
	ct_q_cond_gr.r_q_cond_gr_id 
FROM v_soil_prof 
	LEFT JOIN v_soil_q ON (v_soil_prof.profid=v_soil_q.profid) 
	INNER JOIN v_q_ord ON (v_soil_prof.rid=v_q_ord.rid AND v_soil_q.qid=v_q_ord.qid) 
	INNER JOIN ct_q_cond_gr ON (v_q_ord.r_q_cond_gr_id=ct_q_cond_gr.r_q_cond_gr_id);

-- v_soil_q_missing provides a list with syntactically missing conditionally mandatory qualifiers for all soil profiles
CREATE VIEW v_soil_q_missing AS 
(SELECT v_soil_prof.profid, 
	'[Add at least either '||ct_q_cond_gr.q_list||']' AS q_corr,
	'['||ct_q_cond_gr.q_abbr_list||'?]' AS q_abbr_corr, 
	ct_q_cond_gr.q_pos, 
	NULL::integer AS sid, 
	NULL AS q_gr_pref 
FROM v_soil_prof 
	LEFT JOIN ct_q_cond_gr ON (v_soil_prof.rid=ct_q_cond_gr.rid) 
	LEFT JOIN v_soil_prof_q_cond_gr_pres ON (v_soil_prof.profid=v_soil_prof_q_cond_gr_pres.profid AND ct_q_cond_gr.r_q_cond_gr_id=v_soil_prof_q_cond_gr_pres.r_q_cond_gr_id)
WHERE v_soil_prof_q_cond_gr_pres.r_q_cond_gr_id Is Null And ct_q_cond_gr.r_q_cond_gr_id Is Not Null) 
UNION ((SELECT q.qprofid AS profid,
	'[Correct specifier use for Dystric and Eutric]' AS q_corr, 
	'[dy../eu..?]' AS q_abbr_corr, 
	CASE WHEN MIN(q.q_pos) Is Null THEN MIN(q.q_supp_abs_order_pos) ELSE MIN(q.q_pos) END +1 AS q_pos_corr,
	NULL::integer AS sid, 
	NULL AS q_gr_pref 
FROM
	(SELECT v_soil_prof.profid AS qprofid, 
		v_soil_q.qid AS qqid, 
		v_q_ord.q_pos, 
		v_q.q_supp_abs_order_pos AS q_supp_abs_order_pos 
	 FROM v_soil_prof 
		LEFT JOIN v_soil_q ON (v_soil_prof.profid=v_soil_q.profid) 
		LEFT JOIN v_q_ord ON (v_soil_prof.rid=v_q_ord.rid AND v_soil_q.qid=v_q_ord.qid) 
		INNER JOIN v_q ON (v_soil_q.qid=v_q.qid) 
	 	LEFT JOIN 
			(SELECT v_soil_q.profid AS profid 
				FROM v_soil_q JOIN v_soil_prof ON (v_soil_q.profid=v_soil_prof.profid) JOIN v_q_ord ON (v_soil_prof.rid=v_q_ord.rid AND v_soil_q.qid=v_q_ord.qid)   
				WHERE v_soil_q.qid IN (270,1650,1680,1920,1950) AND v_q_ord.q_role < 60
			) AS qexcl ON (v_soil_prof.profid=qexcl.profid) 
			LEFT JOIN v_soil_q_corr_sel_prep4 ON (qexcl.profid=v_soil_q_corr_sel_prep4.profid) 
	WHERE v_soil_q.qid IN (1620, 1860, 1890) AND v_soil_q.sid IS NULL AND v_q_ord.q_role<60 AND (qexcl.profid IS NULL OR v_q_ord.q_pos < 1000) AND v_soil_q_corr_sel_prep4.profid IS NULL)
	AS q 
GROUP BY q.qprofid 
HAVING Count(q.qqid)>=2));

-- v_soil_q_supp_missing provides the list of syntactically missing (sub)qualifier group members for each soil profile (it might be none)
CREATE VIEW v_soil_q_supp_missing AS
(SELECT v_soil_q_missing.profid,
    v_soil_q_missing.q_corr,
    ('[add at least '::text || v_soil_q_missing.q_abbr_corr) || ']'::text AS q_abbr_corr,
    v_soil_q_missing.q_pos,
    v_soil_q_missing.sid,
    v_soil_q_missing.q_gr_pref 
   FROM v_soil_q_missing
  WHERE v_soil_q_missing.q_pos >= 1000 
  ORDER BY v_soil_q_missing.profid)  
UNION (SELECT v_soil_q.profid,
        CASE
            WHEN MIN(v_soil_q.qid) = 1860 AND v_q_ord2.q_role<60 THEN '[Add Dystric or correct specifier of Eutric]'::text
            WHEN MIN(v_soil_q.qid) = 1620 AND v_q_ord2.q_role<60 THEN '[Add Eutric or correct specifier of Dystric]'::text
        END AS q_corr,
        CASE
            WHEN MIN(v_soil_q.qid) = 1860 AND v_q_ord2.q_role<60 THEN '[dy?]'::text
            WHEN MIN(v_soil_q.qid) = 1620 AND v_q_ord2.q_role<60 THEN '[eu?]'::text
        END AS q_abbr_corr,
    min(v_q_ord.q_pos) AS q_pos_corr,
    NULL::integer AS sid,
    NULL::text AS q_gr_pref 
   FROM v_soil_q
     JOIN ct_q ON v_soil_q.qid = ct_q.qid
     JOIN v_q_ord ON v_q_ord.qid =
        CASE
            WHEN v_soil_q.qid = 1860 THEN 1620
            ELSE 1860
        END
	 JOIN v_q_ord AS v_q_ord2 ON (v_q_ord.rid=v_q_ord2.rid)
  WHERE ct_q.q_s_rule = 3 AND (v_q_ord2.qid=(CASE WHEN v_q_ord.qid=1620 THEN 1860 ELSE 1620 END) And v_q_ord.rid=20 And v_q_ord.qid=1860) 
  GROUP BY v_soil_q.profid, ct_q.q_mgr, v_q_ord2.q_role 
 HAVING count(v_soil_q.sid) = 32 AND count(v_soil_q.qid) = 32);

-- v_soil_q_supp extracts all supplementary qualifiers from v_soil_q_supp_prep and combines them with the missing (sub)qualifiers from v_soil_q_supp_missing
CREATE VIEW v_soil_q_supp AS 
(SELECT DISTINCT v_soil_q_supp_prep.profid, 
	v_soil_q_supp_prep.q_corr, 
	v_soil_q_supp_prep.q_abbr_corr, 
	v_soil_q_supp_prep.q_pos, 
	v_soil_q_supp_prep.sid, 
	v_soil_q_supp_prep.q_role, 
	CASE WHEN (v_soil_q_supp_prep.q_role = 10 And v_soil_q_supp_prep.q_role <= 19) THEN 20 WHEN v_soil_q_supp_prep.q_role=30 And v_soil_q_supp_prep.sid<>3 And v_soil_q_supp_prep.sid<>10 THEN 2 WHEN v_soil_q_supp_prep.q_role=45 THEN 40 ELSE v_soil_q_supp_prep.q_role END AS q_role_corr 
FROM v_soil_q_supp_prep) 
UNION 
(SELECT v_soil_q_supp_missing.profid, 
	v_soil_q_supp_missing.q_corr, 
	v_soil_q_supp_missing.q_abbr_corr, 
	v_soil_q_supp_missing.q_pos, 
	v_soil_q_supp_missing.sid, 
	20::INTEGER As q_role, 
	20::INTEGER As q_role_corr 
FROM v_soil_q_supp_missing);

-- The supplementary (sub)qualifiers v_soil_q_supp can be ordered, but need a rank in the form of a continuous numbering so that the ordered name elements can finally be combined to the soil name. This continuous numbering is done, and afterwards the first, second, etc. (sub)qualifiers for each soil are identified.
-- Add a continuous numbering to v_soil_q_supp as v_soil_q_supp_num
CREATE VIEW v_soil_q_supp_num AS 
SELECT DISTINCT v_soil_q_supp.profid, 
	v_soil_q_supp.q_corr AS q, 
	v_soil_q_supp.q_abbr_corr AS q_abbr, 
	v_soil_q_supp.q_pos, 
	v_soil_q_supp.sid, 
	((SELECT count (q_pos) FROM v_soil_q_supp  As Temp WHERE ((Temp.q_pos < v_soil_q_supp.q_pos) And (Temp.profid = v_soil_q_supp.profid)))+1) AS Nr 
FROM v_soil_q_supp;

-- The following views v_soil_q_supp1 to v_soil_q_supp12 identifiy for each soil which supplementary (sub)qualifier stands in first, second, ..., 11th, 12th position in the final soil name
CREATE VIEW v_soil_q_supp1 AS 
SELECT v_soil_q_supp_num.profid, 
	v_soil_q_supp_num.q AS s1 
FROM v_soil_q_supp_num 
WHERE (((v_soil_q_supp_num.Nr)=1));

CREATE VIEW v_soil_q_supp2 AS 
SELECT v_soil_q_supp_num.profid, 
	v_soil_q_supp_num.q AS s2 
FROM v_soil_q_supp_num 
WHERE (((v_soil_q_supp_num.Nr)=2));

CREATE VIEW v_soil_q_supp3 AS 
SELECT v_soil_q_supp_num.profid, 
	v_soil_q_supp_num.q AS s3 
FROM v_soil_q_supp_num 
WHERE (((v_soil_q_supp_num.Nr)=3));

CREATE VIEW v_soil_q_supp4 AS 
SELECT v_soil_q_supp_num.profid, 
	v_soil_q_supp_num.q AS s4 
FROM v_soil_q_supp_num 
WHERE (((v_soil_q_supp_num.Nr)=4));

CREATE VIEW v_soil_q_supp5 AS 
SELECT v_soil_q_supp_num.profid, 
	v_soil_q_supp_num.q AS s5 
FROM v_soil_q_supp_num 
WHERE (((v_soil_q_supp_num.Nr)=5));

CREATE VIEW v_soil_q_supp6 AS 
SELECT v_soil_q_supp_num.profid, 
	v_soil_q_supp_num.q AS s6 
FROM v_soil_q_supp_num 
WHERE (((v_soil_q_supp_num.Nr)=6));

CREATE VIEW v_soil_q_supp7 AS 
SELECT v_soil_q_supp_num.profid, 
	v_soil_q_supp_num.q AS s7 
FROM v_soil_q_supp_num 
WHERE (((v_soil_q_supp_num.Nr)=7));

CREATE VIEW v_soil_q_supp8 AS 
SELECT v_soil_q_supp_num.profid, 
	v_soil_q_supp_num.q AS s8 
FROM v_soil_q_supp_num 
WHERE (((v_soil_q_supp_num.Nr)=8));

CREATE VIEW v_soil_q_supp9 AS 
SELECT v_soil_q_supp_num.profid, 
	v_soil_q_supp_num.q AS s9 
FROM v_soil_q_supp_num 
WHERE (((v_soil_q_supp_num.Nr)=9));

CREATE VIEW v_soil_q_supp10 AS 
SELECT v_soil_q_supp_num.profid, 
	v_soil_q_supp_num.q AS s10 
FROM v_soil_q_supp_num 
WHERE (((v_soil_q_supp_num.Nr)=10));

CREATE VIEW v_soil_q_supp11 AS 
SELECT v_soil_q_supp_num.profid, 
	v_soil_q_supp_num.q AS s11 
FROM v_soil_q_supp_num 
WHERE (((v_soil_q_supp_num.Nr)=11));

CREATE VIEW v_soil_q_supp12 AS 
SELECT v_soil_q_supp_num.profid, 
	v_soil_q_supp_num.q AS s12 
FROM v_soil_q_supp_num 
WHERE (((v_soil_q_supp_num.Nr)=12));

CREATE VIEW v_soil_q_supp13 AS 
SELECT v_soil_q_supp_num.profid, 
	v_soil_q_supp_num.q AS s13 
FROM v_soil_q_supp_num 
WHERE (((v_soil_q_supp_num.Nr)=13));

CREATE VIEW v_soil_q_supp14 AS 
SELECT v_soil_q_supp_num.profid, 
	v_soil_q_supp_num.q AS s14 
FROM v_soil_q_supp_num 
WHERE (((v_soil_q_supp_num.Nr)=14));

CREATE VIEW v_soil_q_supp15 AS 
SELECT v_soil_q_supp_num.profid, 
	v_soil_q_supp_num.q AS s15 
FROM v_soil_q_supp_num 
WHERE (((v_soil_q_supp_num.Nr)=15));

-- For the abbreviated WRB soil name, supplementary qualifiers need a different handling than the principal qualifiers - it needes to differentiate between texture qualifiers, supplementary qualifiers and applicable, non-listed qualifiers
-- Add a continuous numbering to v_soil_q_supp as v_soil_q_suppc_num
CREATE VIEW v_soil_q_suppc_num AS 
SELECT DISTINCT v_soil_q_supp.profid, 
	v_soil_q_supp.q_abbr_corr AS q_abbr, 
	v_soil_q_supp.q_pos, 
	v_soil_q_supp.q_role_corr AS q_role, 
	v_soil_q_supp.sid, 
	((SELECT count (q_pos) FROM v_soil_q_supp  As Temp WHERE ((Temp.q_pos < v_soil_q_supp.q_pos) And (Temp.profid = v_soil_q_supp.profid) And (Temp.q_role_corr = v_soil_q_supp.q_role_corr)))+1) AS Nr 
FROM v_soil_q_supp;

-- The following views v_soil_q_suppc_gr2_1 to v_soil_q_suppc_gr2_8 identifiy for each soil which supplementary (sub)qualifier's code stands in first, second, ..., 7th, 8th position of the non-texture supplementary (sub)qualifiers in the final abbreviated soil name
CREATE VIEW v_soil_q_suppc_gr2_1 AS 
SELECT v_soil_q_suppc_num.profid, 
	v_soil_q_suppc_num.q_abbr AS s1c 
FROM v_soil_q_suppc_num 
WHERE (v_soil_q_suppc_num.q_role>=20 And v_soil_q_suppc_num.q_role<=29) And v_soil_q_suppc_num.Nr=1;

CREATE VIEW v_soil_q_suppc_gr2_2 AS 
SELECT v_soil_q_suppc_num.profid, 
	v_soil_q_suppc_num.q_abbr AS s2c 
FROM v_soil_q_suppc_num 
WHERE (v_soil_q_suppc_num.q_role>=20 And v_soil_q_suppc_num.q_role<=29) And v_soil_q_suppc_num.Nr=2;

CREATE VIEW v_soil_q_suppc_gr2_3 AS 
SELECT v_soil_q_suppc_num.profid, 
	v_soil_q_suppc_num.q_abbr AS s3c 
FROM v_soil_q_suppc_num 
WHERE (v_soil_q_suppc_num.q_role>=20 And v_soil_q_suppc_num.q_role<=29) And v_soil_q_suppc_num.Nr=3;

CREATE VIEW v_soil_q_suppc_gr2_4 AS 
SELECT v_soil_q_suppc_num.profid, 
	v_soil_q_suppc_num.q_abbr AS s4c 
FROM v_soil_q_suppc_num 
WHERE (v_soil_q_suppc_num.q_role>=20 And v_soil_q_suppc_num.q_role<=29) And v_soil_q_suppc_num.Nr=4;

CREATE VIEW v_soil_q_suppc_gr2_5 AS 
SELECT v_soil_q_suppc_num.profid, 
	v_soil_q_suppc_num.q_abbr AS s5c 
FROM v_soil_q_suppc_num 
WHERE (v_soil_q_suppc_num.q_role>=20 And v_soil_q_suppc_num.q_role<=29) And v_soil_q_suppc_num.Nr=5;

CREATE VIEW v_soil_q_suppc_gr2_6 AS 
SELECT v_soil_q_suppc_num.profid, 
	v_soil_q_suppc_num.q_abbr AS s6c 
FROM v_soil_q_suppc_num 
WHERE (v_soil_q_suppc_num.q_role>=20 And v_soil_q_suppc_num.q_role<=29) And v_soil_q_suppc_num.Nr=6;

CREATE VIEW v_soil_q_suppc_gr2_7 AS 
SELECT v_soil_q_suppc_num.profid, 
	v_soil_q_suppc_num.q_abbr AS s7c 
FROM v_soil_q_suppc_num 
WHERE (v_soil_q_suppc_num.q_role>=20 And v_soil_q_suppc_num.q_role<=29) And v_soil_q_suppc_num.Nr=7;

CREATE VIEW v_soil_q_suppc_gr2_8 AS 
SELECT v_soil_q_suppc_num.profid, 
	v_soil_q_suppc_num.q_abbr AS s8c 
FROM v_soil_q_suppc_num 
WHERE (v_soil_q_suppc_num.q_role>=20 And v_soil_q_suppc_num.q_role<=29) And v_soil_q_suppc_num.Nr=8;

-- The following views v_soil_q_suppc_gr3_1 to v_soil_q_suppc_gr3_4 identifiy for each soil which texture (sub)qualifier's code stands in 1st, 2nd, 3rd, 4th (more texture qualifiers are not possible) position of the texture supplementary (sub)qualifiers in the final abbreviated soil name
CREATE VIEW v_soil_q_suppc_gr3_1 AS 
SELECT v_soil_q_suppc_num.profid, 
	v_soil_q_suppc_num.q_abbr AS t1c 
FROM v_soil_q_suppc_num 
WHERE v_soil_q_suppc_num.q_role=30 And v_soil_q_suppc_num.Nr=1;

CREATE VIEW v_soil_q_suppc_gr3_2 AS 
SELECT v_soil_q_suppc_num.profid, 
	v_soil_q_suppc_num.q_abbr AS t2c 
FROM v_soil_q_suppc_num 
WHERE v_soil_q_suppc_num.q_role=30 And v_soil_q_suppc_num.Nr=2;

CREATE VIEW v_soil_q_suppc_gr3_3 AS 
SELECT v_soil_q_suppc_num.profid, 
	v_soil_q_suppc_num.q_abbr AS t3c 
FROM v_soil_q_suppc_num 
WHERE v_soil_q_suppc_num.q_role=30 And v_soil_q_suppc_num.Nr=3;

CREATE VIEW v_soil_q_suppc_gr3_4 AS 
SELECT v_soil_q_suppc_num.profid, 
	v_soil_q_suppc_num.q_abbr AS t4c 
FROM v_soil_q_suppc_num 
WHERE v_soil_q_suppc_num.q_role=30 And v_soil_q_suppc_num.Nr=4;

-- The following views v_soil_q_suppc_gr4_1 to v_soil_q_suppc_gr4_8 identifiy for each soil which non-listed supplementary (sub)qualifier's code stands in 1st, 2nd, ..., 7th, 8th position of the non-listed supplementary (sub)qualifiers in the final abbreviated soil name
CREATE VIEW v_soil_q_suppc_gr4_1 AS 
SELECT v_soil_q_suppc_num.profid, 
	v_soil_q_suppc_num.q_abbr AS nl1c 
FROM v_soil_q_suppc_num 
WHERE (v_soil_q_suppc_num.q_role>=40 And v_soil_q_suppc_num.q_role<=49) And v_soil_q_suppc_num.Nr=1;

CREATE VIEW v_soil_q_suppc_gr4_2 AS 
SELECT v_soil_q_suppc_num.profid, 
	v_soil_q_suppc_num.q_abbr AS nl2c 
FROM v_soil_q_suppc_num 
WHERE (v_soil_q_suppc_num.q_role>=40 And v_soil_q_suppc_num.q_role<=49) And v_soil_q_suppc_num.Nr=2;

CREATE VIEW v_soil_q_suppc_gr4_3 AS 
SELECT v_soil_q_suppc_num.profid, 
	v_soil_q_suppc_num.q_abbr AS nl3c 
FROM v_soil_q_suppc_num 
WHERE (v_soil_q_suppc_num.q_role>=40 And v_soil_q_suppc_num.q_role<=49) And v_soil_q_suppc_num.Nr=3;

CREATE VIEW v_soil_q_suppc_gr4_4 AS 
SELECT v_soil_q_suppc_num.profid, 
	v_soil_q_suppc_num.q_abbr AS nl4c 
FROM v_soil_q_suppc_num 
WHERE (v_soil_q_suppc_num.q_role>=40 And v_soil_q_suppc_num.q_role<=49) And v_soil_q_suppc_num.Nr=4;

CREATE VIEW v_soil_q_suppc_gr4_5 AS 
SELECT v_soil_q_suppc_num.profid, 
	v_soil_q_suppc_num.q_abbr AS nl5c 
FROM v_soil_q_suppc_num 
WHERE (v_soil_q_suppc_num.q_role>=40 And v_soil_q_suppc_num.q_role<=49) And v_soil_q_suppc_num.Nr=5;

CREATE VIEW v_soil_q_suppc_gr4_6 AS 
SELECT v_soil_q_suppc_num.profid, 
	v_soil_q_suppc_num.q_abbr AS nl6c 
FROM v_soil_q_suppc_num 
WHERE (v_soil_q_suppc_num.q_role>=40 And v_soil_q_suppc_num.q_role<=49) And v_soil_q_suppc_num.Nr=6;

CREATE VIEW v_soil_q_suppc_gr4_7 AS 
SELECT v_soil_q_suppc_num.profid, 
	v_soil_q_suppc_num.q_abbr AS nl7c 
FROM v_soil_q_suppc_num 
WHERE (v_soil_q_suppc_num.q_role>=40 And v_soil_q_suppc_num.q_role<=49) And v_soil_q_suppc_num.Nr=7;

CREATE VIEW v_soil_q_suppc_gr4_8 AS 
SELECT v_soil_q_suppc_num.profid, 
	v_soil_q_suppc_num.q_abbr AS nl8c 
FROM v_soil_q_suppc_num 
WHERE (v_soil_q_suppc_num.q_role>=40 And v_soil_q_suppc_num.q_role<=49) And v_soil_q_suppc_num.Nr=8;


-- PRINCIPAL (sub)qualifier handling
-- The following cascade of views from v_soil_q_princ_prep1 to v_soil_q_princ identifies missing (sub)qualifier groups and formulate a statement for the final soil name and defines the position where this explanation shall be added (which is the position of the first of the conditionally applying (sub)qualifier)
-- v_soil_q_princ_prep1 provides all principal qualifiers for each soil profile from v_soil_q_corr_sel (which is the corrected (sub)qualifier list for each soil profile)
CREATE VIEW v_soil_q_princ_prep1 AS 
SELECT v_soil_q_corr_sel.profid, 
	v_soil_q_corr_sel.q_corr, 
	v_soil_q_corr_sel.q_abbr_corr, 
	((CASE WHEN (v_soil_q_corr_sel.q_pos_corr IS NOT Null) THEN v_soil_q_corr_sel.q_pos_corr ELSE v_soil_q_corr_sel.q_pos END) + (CASE WHEN (v_soil_q_corr_sel.sid Is Not Null AND v_soil_q_corr_sel.qid NOT IN (1620, 1860) AND MOD(v_soil_q_corr_sel.q_pos_corr, 10)=0) THEN v_soil_q_corr_sel.sid ELSE 0 END::integer)) AS q_pos, 
	v_soil_q_corr_sel.sid, 
	v_q_ord.q_gr_pref 
FROM (v_q_ord INNER JOIN v_soil_prof ON v_q_ord.rid=v_soil_prof.rid) INNER JOIN v_soil_q_corr_sel ON (v_q_ord.qid=v_soil_q_corr_sel.qid) AND (v_soil_prof.profid=v_soil_q_corr_sel.profid) 
WHERE ((CASE WHEN v_soil_q_corr_sel.q_pos_corr Is Not Null THEN v_soil_q_corr_sel.q_pos_corr ELSE v_q_ord.q_pos END + CASE WHEN v_soil_q_corr_sel.sid Is Not Null THEN v_soil_q_corr_sel.sid ELSE 0 END)<1000 And 
	((v_q_ord.q_gr_pref)>0 Or (v_q_ord.q_gr_pref) Is Null)) AND (v_q_ord.sid=v_soil_q_corr_sel.sid OR v_q_ord.sid IS NULL) 
ORDER BY v_soil_prof.profid, CASE WHEN v_q_ord.q_pos Is Not Null THEN v_q_ord.q_pos ELSE v_soil_q_corr_sel.q_pos_corr END;

-- v_soil_q_princ_prep1a checks whether there is more than one subqualifier on the same position with the same specifier for a soil profile 
CREATE VIEW v_soil_q_princ_prep1a AS 
SELECT v_soil_q_princ_prep1.profid, 
	v_soil_q_princ_prep1.q_pos AS q_c, 
	v_soil_q_princ_prep1.sid AS sid 
FROM v_soil_q_princ_prep1 
WHERE v_soil_q_princ_prep1.sid NOT IN (3,8,10) 
GROUP BY v_soil_q_princ_prep1.profid, v_soil_q_princ_prep1.q_pos, v_soil_q_princ_prep1.sid 
HAVING (((Count(v_soil_q_princ_prep1.q_pos))>1));

CREATE VIEW v_q_pr_div_Haplic AS 
SELECT t_soil_prof.profid, t_soil_prof.rid, ct_r.r, t_soil_q.qid, ct_q.q 
FROM ((t_soil_prof INNER JOIN ct_r ON t_soil_prof.rid = ct_r.rid) INNER JOIN t_soil_q ON t_soil_prof.profid = t_soil_q.profid) INNER JOIN ct_q ON t_soil_q.qid = ct_q.qid 
WHERE (((t_soil_prof.rid) In (4,6,7,8,12,16,17,18,19,20,22,23,25,26,27,28)) AND ((ct_q.q)='Haplic'));

-- v_soil_q_princ_missing provides the list of missing (sub)qualifier group members for each soil profile (it might be none)
CREATE VIEW v_soil_q_princ_missing AS  
(SELECT v_soil_q_missing.profid, 
	v_soil_q_missing.q_corr, 
	'[Add at least either '||v_soil_q_missing.q_abbr_corr||']' As q_abbr_corr,
	v_soil_q_missing.q_pos, 
	v_soil_q_missing.sid,
	v_soil_q_missing.q_gr_pref 
FROM v_soil_q_missing 
WHERE v_soil_q_missing.q_pos < 1000) 
UNION (
SELECT v_soil_q.profid, 
	CASE WHEN MIN(v_soil_q.qid)=1860 AND v_q_ord2.q_role<60 THEN '[Add Dystric]' WHEN MIN(v_soil_q.qid)=1620 AND v_q_ord2.q_role<60 THEN '[Add Eutric]' END As q_corr, 
	CASE WHEN MIN(v_soil_q.qid)=1860 AND v_q_ord2.q_role<60 THEN '[dy]' WHEN MIN(v_soil_q.qid)=1620 AND v_q_ord2.q_role<60 THEN '[eu]' END As q_abbr_corr, 
	MIN(v_q_ord.q_pos) AS q_pos_corr,
	Null As sid, 
	Null As q_gr_pref
FROM v_soil_q INNER JOIN ct_q ON (v_soil_q.qid=ct_q.qid) INNER JOIN v_q_ord ON (v_q_ord.qid=CASE WHEN (v_soil_q.qid)=1860 THEN 1620 ELSE 1860 END) JOIN v_q_ord AS v_q_ord2 ON (v_q_ord.rid=v_q_ord2.rid)   
WHERE ct_q.q_s_rule=3 AND (v_q_ord2.qid=(CASE WHEN v_q_ord.qid=1620 THEN 1860 ELSE 1620 END) And v_q_ord.rid=20 And v_q_ord.qid=1860)
GROUP BY v_soil_q.profid, ct_q.q_mgr, v_q_ord2.q_role 
HAVING Count(v_soil_q.sid)=32 And Count(v_soil_q.qid)=32);

-- v_soil_q_princ_prep2 combines the list of missing qualifiers (from v_soil_q_princ_missing) with a list of the Haplic qualifier if this has correctly been applied by the DB user
CREATE VIEW v_soil_q_princ_prep2 AS 
(SELECT v_soil_q_princ_missing.profid, 
	v_soil_q_princ_missing.q_corr, 
	v_soil_q_princ_missing.q_abbr_corr, 
	v_soil_q_princ_missing.q_pos, 
	v_soil_q_princ_missing.sid::integer, 
	v_soil_q_princ_missing.q_gr_pref::integer 
FROM v_soil_q_princ_missing) 
UNION (SELECT t_soil_prof.profid, 
	'Haplic'::text AS q_corr, 
	'ha'::text AS q_abbr_corr, 
	10::integer AS q_pos_corr, 
	Null AS sid, 
	Null AS q_gr_pref 
FROM (((t_soil_prof LEFT JOIN v_q_pr_div_Haplic ON t_soil_prof.profid = v_q_pr_div_Haplic.profid) LEFT JOIN v_soil_q_supp ON t_soil_prof.profid = v_soil_q_supp.profid) LEFT JOIN v_soil_q_princ_prep1 AS v_soil_q_princ_prep1_1 ON v_soil_q_supp.profid = v_soil_q_princ_prep1_1.profid) LEFT JOIN v_soil_q_princ_prep1 ON v_q_pr_div_Haplic.profid = v_soil_q_princ_prep1.profid 
GROUP BY t_soil_prof.profid, 'Haplic'::text, 'ha'::text, 10::integer, Null::integer, Null::integer, v_soil_q_princ_prep1.profid, v_soil_q_supp.profid, v_q_pr_div_Haplic.profid, t_soil_prof.rid, v_soil_q_princ_prep1_1.q_corr 
HAVING (((v_soil_q_princ_prep1.profid) Is Null) AND ((v_q_pr_div_Haplic.profid) Is Not Null) AND ((t_soil_prof.rid) In (4,6,7,8,12,16,17,18,19,20,22,23,25,26,27,28))) OR 
	   (((v_soil_q_princ_prep1.profid) Is Null) AND ((v_soil_q_supp.profid) Is Not Null) AND ((v_q_pr_div_Haplic.profid) Is Null) AND ((t_soil_prof.rid) In (4,6,7,8,12,16,17,18,19,20,22,23,25,26,27,28)) AND ((v_soil_q_princ_prep1_1.q_corr) Is Null)));
	   -- with soil names with supplemenntary qual. only: (((v_soil_q_princ_prep1.profid) Is Null) AND ((v_soil_q_supp.profid) Is Not Null) AND ((v_q_pr_div_Haplic.profid) Is Null) AND ((t_soil_prof.rid) In (4,6,7,8,12,16,17,18,19,20,22,23,25,26,27,28)) AND ((v_soil_q_princ_prep1_1.q_corr) Is Null)));

-- v_soil_q_princ combines the results of v_soil_q_princ_prep1 (filtered by v_soil_q_princ_prep1a selected profiles) and v_soil_q_princ_prep2; it holds the complete list of principal qualifiers for each soil profile in t_soil_prof with the ordering number for each name element, completed by missing qualifier information
CREATE VIEW v_soil_q_princ AS 
(SELECT v_soil_q_princ_prep1.profid, 
		v_soil_q_princ_prep1.q_corr, 
		v_soil_q_princ_prep1.q_abbr_corr, 
		v_soil_q_princ_prep1.q_pos, 
		v_soil_q_princ_prep1.sid, 
		v_soil_q_princ_prep1.q_gr_pref::integer 
	FROM v_soil_q_princ_prep1 LEFT JOIN v_soil_q_princ_prep1a ON (v_soil_q_princ_prep1.profid = v_soil_q_princ_prep1a.profid) AND (v_soil_q_princ_prep1.q_pos = v_soil_q_princ_prep1a.q_c) AND (v_soil_q_princ_prep1.sid = v_soil_q_princ_prep1a.sid)
	WHERE (((v_soil_q_princ_prep1a.profid) Is Null)))  
UNION (SELECT v_soil_q_princ_prep2.profid, 
	v_soil_q_princ_prep2.q_corr, 
	v_soil_q_princ_prep2.q_abbr_corr, 
	v_soil_q_princ_prep2.q_pos, 
	v_soil_q_princ_prep2.sid, 
	v_soil_q_princ_prep2.q_gr_pref::integer 
FROM v_soil_q_princ_prep2);

-- The principal (sub)qualifiers and missing qualifier information of v_soil_q_princ can be ordered, but need a rank in the form of a continuous numbering so that the ordered name elements can finally be combined to the soil name. This continuous numbering is done, and afterwards the first, second, etc. (sub)qualifiers for each soil are identified.
-- Add a continuous numbering to v_soil_q_princ as v_soil_q_princ_num
CREATE VIEW v_soil_q_princ_num AS 
SELECT v_soil_q_princ.profid, 
	v_soil_q_princ.q_corr AS q, 
	v_soil_q_princ.q_abbr_corr AS q_abbr, 
	v_soil_q_princ.q_pos, 
	v_soil_q_princ.sid, 
	((SELECT count (q_pos) FROM v_soil_q_princ  As Temp WHERE ((Temp.q_pos < v_soil_q_princ.q_pos) And (Temp.profid = v_soil_q_princ.profid)))+1) AS Nr 
FROM v_soil_q_princ 
ORDER BY v_soil_q_princ.profid, v_soil_q_princ.q_pos;

-- The following views v_soil_q_princ1 to v_soil_q_princ10 identifiy for each soil which principal (sub)qualifier stands in first, second, ..., 9th, 10th position in the final soil name
CREATE VIEW v_soil_q_princ1 AS 
SELECT v_soil_q_princ_num.profid, 
	v_soil_q_princ_num.q AS p1, 
	v_soil_q_princ_num.q_abbr AS p1c 
FROM v_soil_q_princ_num 
WHERE (((v_soil_q_princ_num.Nr)=1));

CREATE VIEW v_soil_q_princ2 AS 
SELECT v_soil_q_princ_num.profid, 
	v_soil_q_princ_num.q AS p2, 
	v_soil_q_princ_num.q_abbr AS p2c 
FROM v_soil_q_princ_num 
WHERE (((v_soil_q_princ_num.Nr)=2));

CREATE VIEW v_soil_q_princ3 AS 
SELECT v_soil_q_princ_num.profid, 
	v_soil_q_princ_num.q AS p3, 
	v_soil_q_princ_num.q_abbr AS p3c 
FROM v_soil_q_princ_num 
WHERE (((v_soil_q_princ_num.Nr)=3));

CREATE VIEW v_soil_q_princ4 AS 
SELECT v_soil_q_princ_num.profid, 
	v_soil_q_princ_num.q AS p4, 
	v_soil_q_princ_num.q_abbr AS p4c 
FROM v_soil_q_princ_num 
WHERE (((v_soil_q_princ_num.Nr)=4));

CREATE VIEW v_soil_q_princ5 AS 
SELECT v_soil_q_princ_num.profid, 
	v_soil_q_princ_num.q AS p5, 
	v_soil_q_princ_num.q_abbr AS p5c 
FROM v_soil_q_princ_num 
WHERE (((v_soil_q_princ_num.Nr)=5));

CREATE VIEW v_soil_q_princ6 AS 
SELECT v_soil_q_princ_num.profid, 
	v_soil_q_princ_num.q AS p6, 
	v_soil_q_princ_num.q_abbr AS p6c 
FROM v_soil_q_princ_num 
WHERE (((v_soil_q_princ_num.Nr)=6));

CREATE VIEW v_soil_q_princ7 AS 
SELECT v_soil_q_princ_num.profid, 
	v_soil_q_princ_num.q AS p7, 
	v_soil_q_princ_num.q_abbr AS p7c 
FROM v_soil_q_princ_num 
WHERE (((v_soil_q_princ_num.Nr)=7));

CREATE VIEW v_soil_q_princ8 AS 
SELECT v_soil_q_princ_num.profid, 
	v_soil_q_princ_num.q AS p8, 
	v_soil_q_princ_num.q_abbr AS p8c 
FROM v_soil_q_princ_num 
WHERE (((v_soil_q_princ_num.Nr)=8));

CREATE VIEW v_soil_q_princ9 AS 
SELECT v_soil_q_princ_num.profid, 
	v_soil_q_princ_num.q AS p9, 
	v_soil_q_princ_num.q_abbr AS p9c 
FROM v_soil_q_princ_num 
WHERE (((v_soil_q_princ_num.Nr)=9));

CREATE VIEW v_soil_q_princ10 AS 
SELECT v_soil_q_princ_num.profid, 
	v_soil_q_princ_num.q AS p10, 
	v_soil_q_princ_num.q_abbr AS p10c 
FROM v_soil_q_princ_num 
WHERE (((v_soil_q_princ_num.Nr)=10));


-- Finally, principal (sub)qualifiers, RSG name (from v_soil_prof) and supplementary (sub)qualifiers are combined in one character string as v_soil_WRB2022_final
CREATE VIEW v_soil_WRB2022_final AS 
SELECT v_soil_prof.profid, 
	(CASE WHEN p10 Is Not Null THEN p10||' ' ELSE '' END)||(CASE WHEN p9 Is Not Null THEN p9||' ' ELSE '' END)||(CASE WHEN p8 Is Not Null THEN p8||' ' ELSE '' END)||(CASE WHEN p7 Is Not Null THEN p7||' ' ELSE '' END)||(CASE WHEN p6 Is Not Null THEN p6||' ' ELSE '' END)||(CASE WHEN p5 Is Not Null THEN p5||' ' ELSE '' END)||(CASE WHEN p4 Is Not Null THEN p4||' ' ELSE '' END)||(CASE WHEN p3 Is Not Null THEN p3||' ' ELSE '' END)||(CASE WHEN p2 Is Not Null THEN p2||' ' ELSE '' END)||(CASE WHEN p1 Is Not Null THEN p1||' ' ELSE '' END)||r||(CASE WHEN s1 Is Not Null THEN ' ('||s1 ELSE '' END)||(CASE WHEN s2 Is Not Null THEN ', '||s2 ELSE '' END)||(CASE WHEN s3 Is Not Null THEN ', '||s3 ELSE '' END)||(CASE WHEN s4 Is Not Null THEN ', '||s4 ELSE '' END)||(CASE WHEN s5 Is Not Null THEN ', '||s5 ELSE '' END)||(CASE WHEN s6 Is Not Null THEN ', '||s6 ELSE '' END)||(CASE WHEN s7 Is Not Null THEN ', '||s7 ELSE '' END)||(CASE WHEN s8 Is Not Null THEN ', '||s8 ELSE '' END)||(CASE WHEN s9 Is Not Null THEN ', '||s9 ELSE '' END)||(CASE WHEN s10 Is Not Null THEN ', '||s10 ELSE '' END)||(CASE WHEN s11 Is Not Null THEN ', '||s11 ELSE '' END)||(CASE WHEN s12 Is Not Null THEN ', '||s12 ELSE '' END)||(CASE WHEN s13 Is Not Null THEN ', '||s13 ELSE '' END)||(CASE WHEN s14 Is Not Null THEN ', '||s14 ELSE '' END)||(CASE WHEN s15 Is Not Null THEN ', '||s15 ELSE '' END)||(CASE WHEN s1 Is Not Null THEN ')' ELSE '' END) AS WRB_2022_name,  
	v_soil_q_princ10.p10, 
	v_soil_q_princ9.p9, 
	v_soil_q_princ8.p8, 
	v_soil_q_princ7.p7, 
	v_soil_q_princ6.p6, 
	v_soil_q_princ5.p5, 
	v_soil_q_princ4.p4, 
	v_soil_q_princ3.p3, 
	v_soil_q_princ2.p2, 
	v_soil_q_princ1.p1, 
	v_r.r, 
	v_soil_q_supp1.s1, 
	v_soil_q_supp2.s2, 
	v_soil_q_supp3.s3, 
	v_soil_q_supp4.s4, 
	v_soil_q_supp5.s5, 
	v_soil_q_supp6.s6, 
	v_soil_q_supp7.s7, 
	v_soil_q_supp8.s8, 
	v_soil_q_supp9.s9, 
	v_soil_q_supp10.s10, 
	v_soil_q_supp11.s11, 
	v_soil_q_supp12.s12, 
	v_soil_q_supp13.s13, 
	v_soil_q_supp14.s14, 
	v_soil_q_supp15.s15 
FROM (((((((((((((((((((((((((v_soil_prof INNER JOIN v_r ON v_soil_prof.rid=v_r.rid) LEFT JOIN v_soil_q_princ1 ON v_soil_prof.profid=v_soil_q_princ1.profid) LEFT JOIN v_soil_q_princ2 ON v_soil_prof.profid=v_soil_q_princ2.profid) LEFT JOIN v_soil_q_princ3 ON v_soil_prof.profid=v_soil_q_princ3.profid) LEFT JOIN v_soil_q_princ4 ON v_soil_prof.profid=v_soil_q_princ4.profid) LEFT JOIN v_soil_q_princ5 ON v_soil_prof.profid=v_soil_q_princ5.profid) LEFT JOIN v_soil_q_princ6 ON v_soil_prof.profid=v_soil_q_princ6.profid) LEFT JOIN v_soil_q_princ7 ON v_soil_prof.profid=v_soil_q_princ7.profid) LEFT JOIN v_soil_q_princ8 ON v_soil_prof.profid=v_soil_q_princ8.profid) LEFT JOIN v_soil_q_princ9 ON v_soil_prof.profid=v_soil_q_princ9.profid) LEFT JOIN v_soil_q_princ10 ON v_soil_prof.profid=v_soil_q_princ10.profid) LEFT JOIN v_soil_q_supp1 ON v_soil_prof.profid=v_soil_q_supp1.profid) LEFT JOIN v_soil_q_supp2 ON v_soil_prof.profid=v_soil_q_supp2.profid) LEFT JOIN v_soil_q_supp3 ON v_soil_prof.profid=v_soil_q_supp3.profid) LEFT JOIN v_soil_q_supp4 ON v_soil_prof.profid=v_soil_q_supp4.profid) LEFT JOIN v_soil_q_supp5 ON v_soil_prof.profid=v_soil_q_supp5.profid) LEFT JOIN v_soil_q_supp6 ON v_soil_prof.profid=v_soil_q_supp6.profid) LEFT JOIN v_soil_q_supp7 ON v_soil_prof.profid=v_soil_q_supp7.profid) LEFT JOIN v_soil_q_supp8 ON v_soil_prof.profid=v_soil_q_supp8.profid) LEFT JOIN v_soil_q_supp9 ON v_soil_prof.profid=v_soil_q_supp9.profid) LEFT JOIN v_soil_q_supp10 ON v_soil_prof.profid=v_soil_q_supp10.profid) LEFT JOIN v_soil_q_supp11 ON v_soil_prof.profid=v_soil_q_supp11.profid) LEFT JOIN v_soil_q_supp12 ON v_soil_prof.profid=v_soil_q_supp12.profid) LEFT JOIN v_soil_q_supp13 ON v_soil_prof.profid=v_soil_q_supp13.profid) LEFT JOIN v_soil_q_supp14 ON v_soil_prof.profid=v_soil_q_supp14.profid) LEFT JOIN v_soil_q_supp15 ON v_soil_prof.profid=v_soil_q_supp15.profid;

-- In addition, principal (sub)qualifier codes, RSG code and supplementary (sub)qualifier codes are combined in one character string as v_soil_WRB2022_abbr_final
CREATE VIEW v_soil_WRB2022_abbr_final AS 
SELECT v_soil_prof.profid, 
	(v_r.r_abbr||(CASE WHEN p1c Is Not Null THEN '-'||p1c ELSE '' END)||(CASE WHEN p2c Is Not Null THEN '.'||p2c ELSE '' END)||(CASE WHEN p3c Is Not Null THEN '.'||p3c ELSE '' END)||(CASE WHEN p4c Is Not Null THEN '.'||p4c ELSE '' END)||(CASE WHEN p5c Is Not Null THEN '.'||p5c ELSE '' END)||(CASE WHEN p6c Is Not Null THEN '.'||p6c ELSE '' END)||(CASE WHEN p7c Is Not Null THEN '.'||p7c ELSE '' END)||(CASE WHEN p8c Is Not Null THEN '.'||p8c ELSE '' END)||(CASE WHEN COALESCE(t1c,s1c,nl1c) Is Not Null THEN ('-'||
		(CASE WHEN t1c Is Not Null THEN t1c ELSE '' END)||(CASE WHEN t2c Is Not Null THEN '.'||t2c ELSE '' END)||(CASE WHEN t3c Is Not Null THEN '.'||t3c ELSE '' END)||(CASE WHEN t4c Is Not Null THEN '.'||t4c ELSE '' END)||CASE WHEN COALESCE(s1c,nl1c) Is Not Null THEN ('-'||			
		(CASE WHEN s1c Is Not Null THEN s1c ELSE '' END)||(CASE WHEN s2c Is Not Null THEN '.'||s2c ELSE '' END)||(CASE WHEN s3c Is Not Null THEN '.'||s3c ELSE '' END)||(CASE WHEN s4c Is Not Null THEN '.'||s4c ELSE '' END)||(CASE WHEN s5c Is Not Null THEN '.'||s5c ELSE '' END)||(CASE WHEN s6c Is Not Null THEN '.'||s6c ELSE '' END)||(CASE WHEN s7c Is Not Null THEN '.'||s7c ELSE '' END)||(CASE WHEN s8c Is Not Null THEN '.'||s8c ELSE '' END)||
		(CASE WHEN nl1c Is Not NULL THEN '-'||nl1c||(CASE WHEN nl2c Is Not Null THEN '.'||nl2c ELSE '' END)||(CASE WHEN nl3c Is Not Null THEN '.'||nl3c ELSE '' END)||(CASE WHEN nl4c Is Not Null THEN '.'||nl4c ELSE '' END)||(CASE WHEN nl5c Is Not Null THEN '.'||nl5c ELSE '' END)||(CASE WHEN nl6c Is Not Null THEN '.'||nl6c ELSE '' END)||(CASE WHEN nl7c Is Not Null THEN '.'||nl7c ELSE '' END)||(CASE WHEN nl8c Is Not Null THEN '.'||nl8c ELSE '' END) ELSE '' END)) ELSE '' END) ELSE '' END)) AS abbr_name, 
	v_r.r_abbr,
	v_soil_q_princ1.p1c, 
	v_soil_q_princ2.p2c, 
	v_soil_q_princ3.p3c, 
	v_soil_q_princ4.p4c, 
	v_soil_q_princ5.p5c, 
	v_soil_q_princ6.p6c, 
	v_soil_q_princ7.p7c, 
	v_soil_q_princ8.p8c, 
	v_soil_q_suppc_gr3_1.t1c, 
	v_soil_q_suppc_gr3_2.t2c, 
	v_soil_q_suppc_gr3_3.t3c, 
	v_soil_q_suppc_gr3_4.t4c,
	v_soil_q_suppc_gr2_1.s1c, 
	v_soil_q_suppc_gr2_2.s2c, 
	v_soil_q_suppc_gr2_3.s3c, 
	v_soil_q_suppc_gr2_4.s4c, 
	v_soil_q_suppc_gr2_5.s5c, 
	v_soil_q_suppc_gr2_6.s6c, 
	v_soil_q_suppc_gr2_7.s7c, 
	v_soil_q_suppc_gr2_8.s8c, 
	v_soil_q_suppc_gr4_1.nl1c, 	
	v_soil_q_suppc_gr4_2.nl2c, 
	v_soil_q_suppc_gr4_3.nl3c, 
	v_soil_q_suppc_gr4_4.nl4c, 
	v_soil_q_suppc_gr4_5.nl5c, 
	v_soil_q_suppc_gr4_6.nl6c, 
	v_soil_q_suppc_gr4_7.nl7c,  
	v_soil_q_suppc_gr4_8.nl8c  
FROM (((((((((((((((((((((((((((((v_soil_prof INNER JOIN v_r ON v_soil_prof.rid=v_r.rid) LEFT JOIN v_soil_q_princ1 ON v_soil_prof.profid=v_soil_q_princ1.profid) LEFT JOIN v_soil_q_princ2 ON v_soil_prof.profid=v_soil_q_princ2.profid) LEFT JOIN v_soil_q_princ3 ON v_soil_prof.profid=v_soil_q_princ3.profid) LEFT JOIN v_soil_q_princ4 ON v_soil_prof.profid=v_soil_q_princ4.profid) LEFT JOIN v_soil_q_princ5 ON v_soil_prof.profid=v_soil_q_princ5.profid) LEFT JOIN v_soil_q_princ6 ON v_soil_prof.profid=v_soil_q_princ6.profid) LEFT JOIN v_soil_q_princ7 ON v_soil_prof.profid=v_soil_q_princ7.profid) LEFT JOIN v_soil_q_princ8 ON v_soil_prof.profid=v_soil_q_princ8.profid) 
	LEFT JOIN v_soil_q_suppc_gr3_1 ON v_soil_prof.profid=v_soil_q_suppc_gr3_1.profid) LEFT JOIN v_soil_q_suppc_gr3_2 ON v_soil_prof.profid=v_soil_q_suppc_gr3_2.profid) LEFT JOIN v_soil_q_suppc_gr3_3 ON v_soil_prof.profid=v_soil_q_suppc_gr3_3.profid) LEFT JOIN v_soil_q_suppc_gr3_4 ON v_soil_prof.profid=v_soil_q_suppc_gr3_4.profid) 
	LEFT JOIN v_soil_q_suppc_gr2_1 ON v_soil_prof.profid=v_soil_q_suppc_gr2_1.profid) LEFT JOIN v_soil_q_suppc_gr2_2 ON v_soil_prof.profid=v_soil_q_suppc_gr2_2.profid) LEFT JOIN v_soil_q_suppc_gr2_3 ON v_soil_prof.profid=v_soil_q_suppc_gr2_3.profid) LEFT JOIN v_soil_q_suppc_gr2_4 ON v_soil_prof.profid=v_soil_q_suppc_gr2_4.profid) LEFT JOIN v_soil_q_suppc_gr2_5 ON v_soil_prof.profid=v_soil_q_suppc_gr2_5.profid) LEFT JOIN v_soil_q_suppc_gr2_6 ON v_soil_prof.profid=v_soil_q_suppc_gr2_6.profid) LEFT JOIN v_soil_q_suppc_gr2_7 ON v_soil_prof.profid=v_soil_q_suppc_gr2_7.profid) LEFT JOIN v_soil_q_suppc_gr2_8 ON v_soil_prof.profid=v_soil_q_suppc_gr2_8.profid)
	LEFT JOIN v_soil_q_suppc_gr4_1 ON v_soil_prof.profid=v_soil_q_suppc_gr4_1.profid) LEFT JOIN v_soil_q_suppc_gr4_2 ON v_soil_prof.profid=v_soil_q_suppc_gr4_2.profid) LEFT JOIN v_soil_q_suppc_gr4_3 ON v_soil_prof.profid=v_soil_q_suppc_gr4_3.profid) LEFT JOIN v_soil_q_suppc_gr4_4 ON v_soil_prof.profid=v_soil_q_suppc_gr4_4.profid) LEFT JOIN v_soil_q_suppc_gr4_5 ON v_soil_prof.profid=v_soil_q_suppc_gr4_5.profid) LEFT JOIN v_soil_q_suppc_gr4_6 ON v_soil_prof.profid=v_soil_q_suppc_gr4_6.profid) LEFT JOIN v_soil_q_suppc_gr4_7 ON v_soil_prof.profid=v_soil_q_suppc_gr4_7.profid) LEFT JOIN v_soil_q_suppc_gr4_8 ON v_soil_prof.profid=v_soil_q_suppc_gr4_8.profid);
-- END