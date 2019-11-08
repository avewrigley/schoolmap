-- MySQL dump 10.13  Distrib 8.0.18, for Linux (x86_64)
--
-- Host: localhost    Database: schoolmap
-- ------------------------------------------------------
-- Server version	8.0.18

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `performance`
--

DROP TABLE IF EXISTS `performance`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `performance` (
  `pupils_primary` int(11) default NULL,
  `ofsted_id` int(10) unsigned NOT NULL,
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
  PRIMARY KEY  (`ofsted_id`),
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
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2019-10-28 17:47:03
