<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
                xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
                xmlns:rss="http://purl.org/rss/1.0/"
                xmlns:dc="http://purl.org/dc/elements/1.1/"
                xmlns:prism="http://purl.org/rss/1.0/modules/prism/"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:output method="text" indent="yes"/>

  <xsl:template match="/">
    <xsl:for-each select="rdf:RDF/rss:item">
      <xsl:apply-templates select="dc:identifier"/>
      <xsl:text>&#x20;</xsl:text>
      <xsl:value-of select="prism:publicationDate"/>
      <xsl:text>&#x20;</xsl:text>
      <xsl:value-of select="rss:title"/>
      <xsl:text>&#x0A;</xsl:text>
    </xsl:for-each>
  </xsl:template>

  <!-- print nothing that's not explicitly output -->
  <xsl:template match="text()"/>

  <!-- omit "info:doi/" at the start of the string -->
  <xsl:template match="dc:identifier[1]">
    <xsl:value-of select="substring(.,10)"/>
  </xsl:template>

</xsl:stylesheet>

