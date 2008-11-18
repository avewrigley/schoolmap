DROP TABLE IF EXISTS `dcsf`;
DROP TABLE IF EXISTS `dcfs`;
CREATE TABLE `dcsf` (
  `pupils_primary` int(11) default NULL,
  `dcsf_id` int(10) unsigned NOT NULL,
  `average_secondary` float default NULL,
  `pupils_secondary` float default NULL,
  `pupils_post16` int(11) default NULL,
  `average_post16` float default NULL,
  `post16_url` varchar(255) default '',
  `secondary_url` varchar(255) default '',
  `primary_url` varchar(255) default '',
  `ks3_url` varchar(255) default '',
  `average_ks3` float default '0',
  `pupils_ks3` int(11) default '0',
  `average_primary` float default NULL,
  PRIMARY KEY  (`dcsf_id`),
  KEY `urls` (`secondary_url`,`primary_url`),
  KEY `urls2` (`ks3_url`,`post16_url`),
  KEY `py` (`primary_url`),
  KEY `sy` (`secondary_url`),
  KEY `ks3y` (`ks3_url`),
  KEY `p16y` (`post16_url`),
  KEY `average_post16` (`average_post16`),
  KEY `average_ks3` (`average_ks3`),
  KEY `average_primary` (`average_primary`),
  KEY `average_secondary` (`average_secondary`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;