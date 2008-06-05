-- MySQL dump 10.11
--
-- Host: localhost    Database: schoolmap
-- ------------------------------------------------------
-- Server version	5.0.32-Debian_7etch5-log

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
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
  `pupils_primary` int(11) default NULL,
  `dfes_id` int(10) unsigned NOT NULL,
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
  PRIMARY KEY  (`dfes_id`),
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

--
-- Table structure for table `ofsted`
--

DROP TABLE IF EXISTS `ofsted`;
CREATE TABLE `ofsted` (
  `ofsted_id` int(10) unsigned NOT NULL,
  `ofsted_url` varchar(255) NOT NULL default '',
  `ofsted_school_id` int(11) NOT NULL default '0',
  PRIMARY KEY  (`ofsted_school_id`),
  UNIQUE KEY `school_id` (`ofsted_id`)
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
  SPATIAL KEY `location` (`location`(32)),
  KEY `lon` (`lon`),
  KEY `lat` (`lat`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `school`
--

DROP TABLE IF EXISTS `school`;
CREATE TABLE `school` (
  `postcode` varchar(100) NOT NULL default '',
  `dfes_id` int(10) unsigned NOT NULL default '0',
  `address` varchar(255) default '',
  `name` varchar(100) NOT NULL default '',
  `ofsted_id` int(10) unsigned default NULL,
  PRIMARY KEY  (`dfes_id`),
  UNIQUE KEY `postcode_name` (`postcode`,`name`),
  KEY `postcode` (`postcode`),
  KEY `name` (`name`)
) ENGINE=MyISAM AUTO_INCREMENT=108604 DEFAULT CHARSET=latin1;

--
-- Table structure for table `url`
--

DROP TABLE IF EXISTS `url`;
CREATE TABLE `url` (
  `modtime` int(11) NOT NULL default '0',
  `url` varchar(255) NOT NULL default '',
  `requested` datetime default NULL,
  PRIMARY KEY  (`url`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2008-06-05  9:54:07