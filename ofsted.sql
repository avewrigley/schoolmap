DROP TABLE IF EXISTS `ofsted`;
CREATE TABLE `ofsted` (
  `type` varchar(255) NOT NULL,
  `ofsted_id` int(10) unsigned NOT NULL,
  `ofsted_url` varchar(255) NOT NULL default '',
  PRIMARY KEY  (`ofsted_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
