-- MySQL dump 10.9
--
-- Host: localhost    Database: schoolmap
-- ------------------------------------------------------
-- Server version	4.1.15-Debian_1-log

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `address`
--

DROP TABLE IF EXISTS `address`;
CREATE TABLE `address` (
  `address` varchar(80) NOT NULL default '',
  `address_loc` point NOT NULL default '',
  PRIMARY KEY  (`address`),
  SPATIAL KEY `address_loc` (`address_loc`(32))
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `dfes`
--

DROP TABLE IF EXISTS `dfes`;
CREATE TABLE `dfes` (
  `region` int(11) NOT NULL default '0',
  `lea` int(11) NOT NULL default '0',
  `pupils_primary` int(11) default NULL,
  `school_id` int(11) NOT NULL default '0',
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
  `year` int(11) NOT NULL default '2005',
  `average_primary` float default NULL,
  PRIMARY KEY  (`school_id`,`year`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `isi`
--

DROP TABLE IF EXISTS `isi`;
CREATE TABLE `isi` (
  `countycountry` varchar(100) NOT NULL default '',
  `boarding_day` varchar(100) default '',
  `town` varchar(100) NOT NULL default '',
  `age_range` varchar(100) default '',
  `school_id` int(11) NOT NULL default '0',
  `isi_url` varchar(100) NOT NULL default '',
  `gender` varchar(100) default '',
  UNIQUE KEY `school_id` (`school_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `keystage`
--

DROP TABLE IF EXISTS `keystage`;
CREATE TABLE `keystage` (
  `name` varchar(255) NOT NULL default '',
  `age` int(11) NOT NULL default '0',
  `description` varchar(255) NOT NULL default ''
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `ofsted`
--

DROP TABLE IF EXISTS `ofsted`;
CREATE TABLE `ofsted` (
  `school_id` int(11) NOT NULL default '0',
  `ofsted_url` varchar(100) NOT NULL default '',
  `lea_id` int(11) NOT NULL default '0',
  `region_id` int(11) NOT NULL default '0',
  `ofsted_school_id` int(11) NOT NULL default '0',
  PRIMARY KEY  (`ofsted_school_id`),
  UNIQUE KEY `school_id` (`school_id`),
  KEY `lea_id` (`lea_id`),
  KEY `region_id` (`region_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `postcode`
--

DROP TABLE IF EXISTS `postcode`;
CREATE TABLE `postcode` (
  `lat` float NOT NULL default '0',
  `lon` float NOT NULL default '0',
  `x` int(11) NOT NULL default '0',
  `y` int(11) NOT NULL default '0',
  `code` varchar(8) NOT NULL default '',
  `location` point NOT NULL default '',
  PRIMARY KEY  (`code`),
  SPATIAL KEY `location` (`location`(32))
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `school`
--

DROP TABLE IF EXISTS `school`;
CREATE TABLE `school` (
  `postcode` varchar(100) NOT NULL default '',
  `school_id` int(10) unsigned NOT NULL auto_increment,
  `address` varchar(255) default '',
  `name` varchar(100) NOT NULL default '',
  PRIMARY KEY  (`school_id`),
  UNIQUE KEY `postcode_name` (`postcode`,`name`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `school_type`
--

DROP TABLE IF EXISTS `school_type`;
CREATE TABLE `school_type` (
  `school_id` int(11) NOT NULL default '0',
  `type` varchar(255) NOT NULL default '',
  PRIMARY KEY  (`school_id`,`type`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `source`
--

DROP TABLE IF EXISTS `source`;
CREATE TABLE `source` (
  `name` varchar(255) NOT NULL default '',
  `url` varchar(255) NOT NULL default '',
  `description` varchar(255) NOT NULL default '',
  PRIMARY KEY  (`name`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `url`
--

DROP TABLE IF EXISTS `url`;
CREATE TABLE `url` (
  `modtime` int(11) NOT NULL default '0',
  `url` varchar(100) NOT NULL default '',
  PRIMARY KEY  (`url`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

