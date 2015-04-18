<?xml version="1.0" encoding="utf-8"?>
<!--
 Copyright 2015 Max Toro Q.

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
-->
<stylesheet version="2.0" exclude-result-prefixes="#all"
   xmlns="http://www.w3.org/1999/XSL/Transform"
   xmlns:xs="http://www.w3.org/2001/XMLSchema"
   xmlns:r="http://maxtoroq.github.io/rng.xsl"
   xmlns:f="http://maxtoroq.github.io/rng.xsl/syntax"
   xmlns:s="http://maxtoroq.github.io/rng.xsl/simplify"
   xmlns:d="http://maxtoroq.github.io/rng.xsl/xsd"
   xpath-default-namespace="http://relaxng.org/ns/structure/1.0">

   <variable name="d:xsd-ns" select="'http://www.w3.org/2001/XMLSchema-datatypes'"/>

   <template match="data[@datatypeLibrary = $d:xsd-ns]/param[not(@name = ('length', 'minLength', 'maxLength', 'pattern', 'minInclusive', 'maxInclusive'))]" mode="s:phase2">
      <sequence select="error($f:error-code, f:error-message(., concat('Parameter ', @name, ' is not valid.')))"/>
   </template>

   <template match="value[@datatypeLibrary = $d:xsd-ns and @type = 'QName' and contains(text(), ':')]" mode="s:phase2">
      <copy copy-namespaces="no">
         <attribute name="ns" select="namespace-uri-for-prefix(substring-before(text(), ':'), .)"/>
         <apply-templates select="@* except @ns" mode="#current"/>
         <value-of select="substring-after(text(), ':')"/>
         <apply-templates select="node() except text()" mode="#current"/>
      </copy>
   </template>

   <template match="value[@datatypeLibrary = $d:xsd-ns]" mode="r:li">
      <param name="n" as="node()"/>
      <param name="context" as="node()?" tunnel="yes"/>

      <sequence select="$n instance of text()
         and d:parse-atomic-type(@type, string($n), ($context, $n)/ancestor-or-self::*[1], ()) eq d:parse-atomic-type(@type, string(), ., @ns)"/>
   </template>

   <template match="data[@datatypeLibrary = $d:xsd-ns]" mode="r:li">
      <param name="n" as="node()"/>
      <param name="context" as="node()?" tunnel="yes"/>

      <choose>
         <when test="$n instance of text()">
            <variable name="data" select="d:parse-atomic-type(@type, string($n), ($context, $n)/ancestor-or-self::*[1], ())"/>
            <choose>
               <when test="not(empty($data))">
                  <variable name="params" as="xs:boolean*">
                     <apply-templates select="param" mode="#current">
                        <with-param name="n" select="$n"/>
                        <with-param name="d" select="$data"/>
                     </apply-templates>
                  </variable>
                  <variable name="valid" select="every $p in $params satisfies $p"/>
                  <choose>
                     <when test="$valid and except">
                        <variable name="matching-items" as="item()+">
                           <apply-templates select="except" mode="r:ul">
                              <with-param name="nodes" select="$n"/>
                           </apply-templates>
                        </variable>
                        <sequence select="$matching-items[1]"/>
                     </when>
                     <otherwise>
                        <sequence select="$valid"/>
                     </otherwise>
                  </choose>
               </when>
               <otherwise>
                  <sequence select="false()"/>
               </otherwise>
            </choose>
         </when>
         <otherwise>
            <sequence select="false()"/>
         </otherwise>
      </choose>
   </template>

   <template match="data[@datatypeLibrary = $d:xsd-ns]/param[@name = 'length']" mode="r:li">
      <param name="d" as="xs:anyAtomicType"/>

      <sequence select="string-length($d) eq (text() cast as xs:integer)"/>
   </template>

   <template match="data[@datatypeLibrary = $d:xsd-ns]/param[@name = 'minLength']" mode="r:li">
      <param name="d" as="xs:anyAtomicType"/>

      <sequence select="string-length($d) ge (text() cast as xs:integer)"/>
   </template>

   <template match="data[@datatypeLibrary = $d:xsd-ns]/param[@name = 'maxLength']" mode="r:li">
      <param name="d" as="xs:anyAtomicType"/>

      <sequence select="string-length($d) le (text() cast as xs:integer)"/>
   </template>

   <template match="data[@datatypeLibrary = $d:xsd-ns]/param[@name = 'pattern']" mode="r:li">
      <param name="d" as="xs:anyAtomicType"/>

      <sequence select="matches(string($d), string())"/>
   </template>

   <template match="data[@datatypeLibrary = $d:xsd-ns]/param[@name = 'minInclusive']" mode="r:li">
      <param name="d" as="xs:anyAtomicType"/>

      <sequence select="$d ge d:parse-atomic-type(../@type, string(), ., ())"/>
   </template>

   <template match="data[@datatypeLibrary = $d:xsd-ns]/param[@name = 'maxInclusive']" mode="r:li">
      <param name="d" as="xs:anyAtomicType"/>

      <sequence select="$d le d:parse-atomic-type(../@type, string(), ., ())"/>
   </template>

   <!--
      Helpers
   -->

   <function name="d:parse-atomic-type" as="xs:anyAtomicType?">
      <param name="local-name" as="xs:string"/>
      <param name="val" as="xs:string"/>
      <param name="context" as="element()?"/>
      <param name="ns" as="xs:string?"/>

      <choose>
         <when test="$local-name eq 'integer'">
            <sequence select="if ($val castable as xs:integer) then $val cast as xs:integer else ()"/>
         </when>
         <when test="$local-name eq 'decimal'">
            <sequence select="if ($val castable as xs:decimal) then $val cast as xs:decimal else ()"/>
         </when>
         <when test="$local-name eq 'double'">
            <sequence select="if ($val castable as xs:double) then $val cast as xs:double else ()"/>
         </when>
         <when test="$local-name eq 'float'">
            <sequence select="if ($val castable as xs:float) then $val cast as xs:float else ()"/>
         </when>
         <when test="$local-name eq 'date'">
            <sequence select="if ($val castable as xs:date) then $val cast as xs:date else ()"/>
         </when>
         <when test="$local-name eq 'time'">
            <sequence select="if ($val castable as xs:time) then $val cast as xs:time else ()"/>
         </when>
         <when test="$local-name eq 'dateTime'">
            <sequence select="if ($val castable as xs:dateTime) then $val cast as xs:dateTime else ()"/>
         </when>
         <when test="$local-name eq 'duration'">
            <sequence select="if ($val castable as xs:duration) then $val cast as xs:duration else ()"/>
         </when>
         <when test="$local-name eq 'string'">
            <sequence select="if ($val castable as xs:string) then $val cast as xs:string else ()"/>
         </when>
         <when test="$local-name eq 'boolean'">
            <sequence select="if ($val castable as xs:boolean) then $val cast as xs:boolean else ()"/>
         </when>
         <when test="$local-name eq 'anyURI'">
            <sequence select="if ($val castable as xs:anyURI) then $val cast as xs:anyURI else ()"/>
         </when>
         <when test="$local-name eq 'gDay'">
            <sequence select="if ($val castable as xs:gDay) then $val cast as xs:gDay else ()"/>
         </when>
         <when test="$local-name eq 'gMonthDay'">
            <sequence select="if ($val castable as xs:gMonthDay) then $val cast as xs:gMonthDay else ()"/>
         </when>
         <when test="$local-name eq 'gMonth'">
            <sequence select="if ($val castable as xs:gMonth) then $val cast as xs:gMonth else ()"/>
         </when>
         <when test="$local-name eq 'gYearMonth'">
            <sequence select="if ($val castable as xs:gYearMonth) then $val cast as xs:gYearMonth else ()"/>
         </when>
         <when test="$local-name eq 'gYear'">
            <sequence select="if ($val castable as xs:gYear) then $val cast as xs:gYear else ()"/>
         </when>
         <when test="$local-name eq 'yearMonthDuration'">
            <sequence select="if ($val castable as xs:yearMonthDuration) then $val cast as xs:yearMonthDuration else ()"/>
         </when>
         <when test="$local-name eq 'dayTimeDuration'">
            <sequence select="if ($val castable as xs:dayTimeDuration) then $val cast as xs:dayTimeDuration else ()"/>
         </when>
         <when test="$local-name eq 'base64Binary'">
            <sequence select="if ($val castable as xs:base64Binary) then $val cast as xs:base64Binary else ()"/>
         </when>
         <when test="$local-name eq 'hexBinary'">
            <sequence select="if ($val castable as xs:hexBinary) then $val cast as xs:hexBinary else ()"/>
         </when>
         <when test="$local-name eq 'QName'">
            <variable name="prefix" select="substring-before($val, ':')"/>
            <sequence select="
               if ($prefix or empty($ns)) then
                  resolve-QName($val, $context)
               else
                  QName($ns, normalize-space($val))
            "/>
         </when>
         <when test="$local-name eq 'NCName'">
            <sequence select="if (not(contains($val, ':')) and $val castable as xs:QName) then QName('', normalize-space($val)) else ()"/>
         </when>
         <otherwise>
            <sequence select="error($f:error-code, concat('The type ', $local-name, ' is not supported.'))"/>
         </otherwise>
      </choose>
   </function>

</stylesheet>
