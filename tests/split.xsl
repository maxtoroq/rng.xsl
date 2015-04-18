<?xml version="1.0" encoding="utf-8"?>
<stylesheet version="2.0" exclude-result-prefixes="#all"
   xmlns:xs="http://www.w3.org/2001/XMLSchema"
   xmlns="http://www.w3.org/1999/XSL/Transform">

   <param name="output-dir" as="xs:string"/>

   <output encoding="utf-8"/>

   <template match="/testSuite">
      <apply-templates select=".//testCase"/>
   </template>

   <template match="testCase">
      
      <variable name="base" select="concat($output-dir, '/', format-number(position(), '000'))"/>

      <apply-templates select="correct | incorrect">
         <with-param name="base" select="$base"/>
      </apply-templates>

      <apply-templates select="resource | dir">
         <with-param name="base" select="$base"/>
      </apply-templates>
      
      <apply-templates select="valid | invalid">
         <with-param name="base" select="$base"/>
      </apply-templates>
   </template>

   <template match="correct">
      <param name="base"/>
      
      <result-document href="{$base}/c.rng" method="xml">
         <call-template name="copy"/>
      </result-document>
   </template>

   <template match="incorrect">
      <param name="base"/>

      <result-document href="{$base}/i.rng" method="xml">
         <call-template name="copy"/>
      </result-document>
   </template>

   <template match="resource">
      <param name="base"/>
      
      <choose>
         <when test="*">
            <result-document href="{$base}/{@name}" method="xml">
               <call-template name="copy"/>
            </result-document>
         </when>
         <otherwise>
            <result-document href="{$base}/{@name}" method="text" encoding="utf-8">
               <value-of select="."/>
            </result-document>
         </otherwise>
      </choose>
   </template>

   <template match="dir">
      <param name="base"/>
      
      <apply-templates select="resource | dir">
         <with-param name="base" select="concat($base, '/', @name)"/>
      </apply-templates>
   </template>

   <template match="valid">
      <param name="base"/>
      
      <result-document href="{$base}/{position()}.v.xml" method="xml">
         <call-template name="copy"/>
      </result-document>
   </template>

   <template match="invalid">
      <param name="base"/>

      <result-document href="{$base}/{position()}.i.xml" method="xml">
         <call-template name="copy"/>
      </result-document>
   </template>

   <template name="copy">
      <if test="@dtd">
         <value-of select="@dtd" disable-output-escaping="yes"/>
      </if>
      <copy-of select="node()"/>
   </template>
   
</stylesheet>
