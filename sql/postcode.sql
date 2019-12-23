DROP TABLE IF EXISTS `postcode`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `postcode` (
      `postcode` varchar(100) NOT NULL DEFAULT '',
      `lat` float NOT NULL DEFAULT '0',
      `lon` float NOT NULL DEFAULT '0',
      PRIMARY KEY (`postcode`),
      KEY `lon` (`lon`),
      KEY `lat` (`lat`),
      KEY `lon_lat` (`lon`,`lat`)
) ENGINE=MyISAM AUTO_INCREMENT=108604 DEFAULT CHARSET=latin1;
