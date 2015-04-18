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
   xmlns:rng="http://relaxng.org/ns/structure/1.0"
   xmlns:f="http://maxtoroq.github.io/rng.xsl/syntax"
   xmlns:s="http://maxtoroq.github.io/rng.xsl/simplify">

   <import href="rng-syntax.xsl"/>

   <variable name="s:rng-ns" select="'http://relaxng.org/ns/structure/1.0'"/>

   <template match="document-node()[rng:*]" mode="s:main">
      <call-template name="s:phase1-main">
         <with-param name="pattern" select="."/>
      </call-template>
   </template>

   <template match="document-node()[not(rng:*)]" mode="s:main">
      <sequence select="error($f:error-code, f:error-message(., concat('Expecting element in ', $s:rng-ns, ' namespace.')))"/>
   </template>

   <template match="node()" mode="s:main">
      <sequence select="error($f:error-code, f:error-message(., 'Expecting document node.'))"/>
   </template>

   <template match="/ | @* | * | text()" priority="-2"
      mode="s:phase1 s:phase2 s:phase3 s:phase4 s:phase5 s:phase6 s:phase7 s:phase8">

      <!-- Comments and PIs are not copied -->

      <copy copy-namespaces="no">
         <apply-templates select="@*, node()" mode="#current"/>
      </copy>
   </template>

   <!--
      ## Phase 1: Inclusions and data types simplification
   -->

   <template name="s:phase1-main">
      <param name="pattern" as="node()"/>

      <variable name="valid-syntax" as="xs:boolean">
         <apply-templates select="$pattern" mode="f:pattern"/>
      </variable>

      <if test="$valid-syntax">
         <variable name="result" as="node()">
            <apply-templates select="$pattern" mode="s:phase1"/>
         </variable>
         <call-template name="s:phase2-main">
            <with-param name="pattern" select="$result"/>
         </call-template>
      </if>
   </template>

   <template match="*" mode="s:phase1" priority="-1">
      <!--
         Phase 1 must preserve namespaces for phase 2.
      -->
      <copy>
         <apply-templates select="@*, node()" mode="#current"/>
      </copy>
   </template>

   <template match="*[not(self::rng:*)] | @*[namespace-uri()]" mode="s:phase1">
      <!--
         4.1. Foreign attributes and elements are removed.
      -->
   </template>

   <template match="*[* and not(text()[normalize-space()])]/text()" mode="s:phase1">
      <!--
         4.2 For each element other than value and param, each child that is a string containing only whitespace characters is removed.
      -->
   </template>

   <template match="@name | @type | @combine" mode="s:phase1">
      <!--
         4.2 Leading and trailing whitespace characters are removed from the value of each name, type and combine attribute.
      -->
      <attribute name="{name()}" select="normalize-space()"/>
   </template>

   <template match="rng:name/text()" mode="s:phase1">
      <!--
         4.2 Leading and trailing whitespace characters are removed from the content of each name element.
      -->
      <value-of select="normalize-space()"/>
   </template>

   <template match="rng:*[not(self::rng:data or self::rng:value)]/@datatypeLibrary" mode="s:phase1">
      <!--
         4.3. Any datatypeLibrary attribute that is on an element other than data or value is removed.
      -->
   </template>

   <template match="rng:data[not(@datatypeLibrary)]" mode="s:phase1">
      <copy>
         <!--
            4.3 For any data or value element that does not have a datatypeLibrary attribute, a datatypeLibrary attribute is added. The value of the added datatypeLibrary attribute is the value of the datatypeLibrary attribute of the nearest ancestor element that has a datatypeLibrary attribute, or the empty string if there is no such ancestor.
         -->
         <attribute name="datatypeLibrary" select="(ancestor::*/@datatypeLibrary)[1]"/>
         <apply-templates select="@*, node()" mode="#current"/>
      </copy>
   </template>

   <template match="rng:value[@type and not(@datatypeLibrary)]" mode="s:phase1">
      <copy>
         <!--
            4.3 For any data or value element that does not have a datatypeLibrary attribute, a datatypeLibrary attribute is added. The value of the added datatypeLibrary attribute is the value of the datatypeLibrary attribute of the nearest ancestor element that has a datatypeLibrary attribute, or the empty string if there is no such ancestor.
         -->
         <attribute name="datatypeLibrary" select="(ancestor::*/@datatypeLibrary)[1]"/>
         <apply-templates select="@*, node()" mode="#current"/>
      </copy>
   </template>

   <template match="rng:value[not(@type)]" mode="s:phase1">
      <copy>
         <!--
            4.4 For any value element that does not have a type attribute, a type attribute is added with value token and the value of the datatypeLibrary attribute is changed to the empty string.
         -->
         <attribute name="type" select="'token'"/>
         <attribute name="datatypeLibrary" select="''"/>
         <apply-templates select="@* except @datatypeLibrary, node()" mode="#current"/>
      </copy>
   </template>

   <template match="rng:externalRef" mode="s:phase1">
      <param name="ref-ns" as="attribute(ns)?"/>
      <param name="docs" select="root()" as="document-node()*" tunnel="yes"/>

      <variable name="ref-doc" select="doc(resolve-uri(s:phase1-transform-href(@href), base-uri()))"/>

      <if test="some $d in $docs satisfies $d is $ref-doc">
         <sequence select="error($f:error-code, f:error-message(., 'Circular reference.'))"/>
      </if>

      <variable name="valid-syntax" as="xs:boolean">
         <apply-templates select="$ref-doc" mode="f:pattern"/>
      </variable>

      <if test="$valid-syntax">
         <apply-templates select="$ref-doc/rng:*" mode="s:phase1-external">
            <with-param name="ref-ns" select="(@ns, $ref-ns)[1]"/>
            <with-param name="docs" select="$docs, $ref-doc" tunnel="yes"/>
         </apply-templates>
      </if>
   </template>

   <template match="/rng:*[not(self::rng:externalRef)]" mode="s:phase1-external">
      <param name="ref-ns" as="attribute(ns)?"/>

      <copy>
         <copy-of select="($ref-ns, @ns)[1]"/>
         <apply-templates select="@* except @ns, node()" mode="s:phase1"/>
      </copy>
   </template>

   <template match="/rng:externalRef" mode="s:phase1-external">
      <param name="ref-ns" as="attribute(ns)?"/>

      <apply-templates select="." mode="s:phase1">
         <with-param name="ref-ns" select="$ref-ns"/>
      </apply-templates>
   </template>

   <template match="rng:include" mode="s:phase1">
      <param name="docs" select="root()" as="document-node()*" tunnel="yes"/>

      <variable name="ref-doc" select="doc(resolve-uri(s:phase1-transform-href(@href), base-uri()))"/>

      <if test="some $d in $docs satisfies $d is $ref-doc">
         <sequence select="error($f:error-code, f:error-message(., 'Circular reference.'))"/>
      </if>

      <variable name="valid-syntax" as="xs:boolean">
         <apply-templates select="$ref-doc" mode="f:pattern"/>
      </variable>

      <if test="$valid-syntax">
         <!--
            4.7 The include element is transformed into a div element. The attributes of the div element are the attributes of the include element other than the href attribute. The children of the div element are the grammar element (after the removal of the start and define components described by the preceding paragraph) followed by the children of the include element. 
         -->
         <element name="div" namespace="{$s:rng-ns}">
            <copy-of select="@* except @href"/>
            <apply-templates select="$ref-doc/rng:grammar" mode="s:phase1-include">
               <with-param name="including" select="true()" tunnel="yes"/>
               <with-param name="include-has-start" select="not(empty(rng:start))" tunnel="yes"/>
               <with-param name="include-defs" select="rng:define/@name/normalize-space()" tunnel="yes"/>
               <with-param name="docs" select="$docs, $ref-doc" tunnel="yes"/>
            </apply-templates>
            <copy-of select="node()"/>
         </element>
      </if>
   </template>

   <template match="/rng:grammar" mode="s:phase1-include">
      <param name="include-has-start" tunnel="yes"/>
      <param name="include-defs" tunnel="yes"/>

      <!--
         4.7
      -->
      <if test="$include-has-start and empty(rng:start)">
         <sequence select="error($f:error-code, f:error-message(., 'If the include element has a start component, then the grammar element must have a start component.'))"/>
      </if>

      <!--
         4.7
      -->
      <if test="not(empty($include-defs))
          and not(every $d in $include-defs satisfies rng:define[@name/normalize-space() eq $d])">
         <sequence select="error($f:error-code, f:error-message(., 'If the include element has a define component, then the grammar element must have a define component with the same name.'))"/>
      </if>

      <!--
         4.7 The grammar element is then renamed to div.
      -->
      <element name="div" namespace="{$s:rng-ns}">
         <apply-templates select="@*, node()" mode="s:phase1"/>
      </element>
   </template>

   <template match="rng:start" mode="s:phase1">
      <param name="including" tunnel="yes"/>
      <param name="include-has-start" tunnel="yes"/>

      <!--
         4.7 If the include element has a start component, then all start components are removed from the grammar element.
      -->

      <if test="not($including and $include-has-start)">
         <next-match/>
      </if>
   </template>

   <template match="rng:define" mode="s:phase1">
      <param name="including" tunnel="yes"/>
      <param name="include-defs" tunnel="yes"/>
      <!--
         4.7 For every define component of the include element, all define components with the same name are removed from the grammar element.
      -->
      <if test="not($including and @name/normalize-space() = $include-defs)">
         <next-match/>
      </if>
   </template>

   <function name="s:phase1-transform-href">
      <param name="href" as="node()"/>
      <!--
         4.5 The href attribute must not include a fragment identifier unless the registration of the media type of the resource identified by the attribute defines the interpretation of fragment identifiers for that media type.
      -->
      <sequence select="if (contains($href, '#')) then 
         error($f:error-code, f:error-message($href, 'The href attribute must not include a fragment identifier.')) 
         else $href"/>
   </function>

   <!--
      ## Phase 2: Names simplification
   -->

   <template name="s:phase2-main">
      <param name="pattern" as="node()"/>

      <variable name="result" as="node()">
         <apply-templates select="$pattern" mode="s:phase2"/>
      </variable>

      <call-template name="s:phase3-main">
         <with-param name="pattern" select="$result"/>
      </call-template>
   </template>

   <template match="rng:element[@name] | rng:attribute[@name]" mode="s:phase2">
      <copy copy-namespaces="no">
         <apply-templates select="@* except @name" mode="#current"/>

         <element name="name" namespace="{$s:rng-ns}">
            <choose>
               <when test="contains(@name, ':')">
                  <!--
                     4.10 For any name element containing a prefix, the prefix is removed and an ns attribute is added replacing any existing ns attribute. The value of the added ns attribute is the value to which the namespace map of the context of the name element maps the prefix. The context must have a mapping for the prefix.
                  -->
                  <attribute name="ns" select="namespace-uri-for-prefix(substring-before(@name, ':'), .)"/>
                  <value-of select="substring-after(@name, ':')"/>
               </when>
               <otherwise>
                  <!--
                     4.8 If an attribute element has a name attribute but no ns attribute, then an ns="" attribute is added to the name child element.
                     
                     4.9 For any name, nsName or value element that does not have an ns attribute, an ns attribute is added. The value of the added ns attribute is the value of the ns attribute of the nearest ancestor element that has an ns attribute, or the empty string if there is no such ancestor.
                  -->
                  <attribute name="ns" select="
                     if (self::rng:attribute) then (@ns, '')[1]
                     else (ancestor-or-self::*/@ns)[1]"/>

                  <value-of select="@name"/>
               </otherwise>
            </choose>
         </element>

         <apply-templates select="node()" mode="#current"/>
      </copy>
   </template>

   <template match="rng:name" mode="s:phase2">
      <copy copy-namespaces="no">
         <choose>
            <when test="contains(text(), ':')">
               <!--
                  4.10 For any name element containing a prefix, the prefix is removed and an ns attribute is added replacing any existing ns attribute. The value of the added ns attribute is the value to which the namespace map of the context of the name element maps the prefix. The context must have a mapping for the prefix.
               -->
               <attribute name="ns" select="namespace-uri-for-prefix(substring-before(text(), ':'), .)"/>
               <apply-templates select="@* except @ns" mode="#current"/>
               <value-of select="substring-after(text(), ':')"/>
               <apply-templates select="node() except text()" mode="#current"/>
            </when>
            <otherwise>
               <if test="not(@ns)">
                  <!--
                     4.9 For any name, nsName or value element that does not have an ns attribute, an ns attribute is added. The value of the added ns attribute is the value of the ns attribute of the nearest ancestor element that has an ns attribute, or the empty string if there is no such ancestor.
                  -->
                  <attribute name="ns" select="(ancestor::*/@ns)[1]"/>
               </if>
               <apply-templates select="@*, node()" mode="#current"/>
            </otherwise>
         </choose>
      </copy>
   </template>

   <template match="rng:nsName[not(@ns)] | rng:value[not(@ns)]" mode="s:phase2">
      <copy copy-namespaces="no">
         <!--
            4.9 For any name, nsName or value element that does not have an ns attribute, an ns attribute is added. The value of the added ns attribute is the value of the ns attribute of the nearest ancestor element that has an ns attribute, or the empty string if there is no such ancestor.
         -->
         <attribute name="ns" select="(ancestor::*/@ns)[1]"/>
         <apply-templates select="@*, node()" mode="#current"/>
      </copy>
   </template>

   <template match="rng:*[not(self::rng:name or self::rng:nsName or self::rng:value)]/@ns" mode="s:phase2">
      <!--
         4.9. Any ns attribute that is on an element other than name, nsName or value is removed.
      -->
   </template>

   <template match="rng:div" mode="s:phase2">
      <!--
         4.11 Each div element is replaced by its children.
      -->
      <apply-templates mode="#current"/>
   </template>

   <!--
      ## Phase 3: Patterns simplification
   -->

   <template name="s:phase3-main">
      <param name="pattern" as="node()"/>

      <variable name="result" as="node()">
         <apply-templates select="$pattern" mode="s:phase3"/>
      </variable>

      <variable name="constraints" as="item()*">
         <apply-templates select="$result" mode="s:phase3-constraints"/>
      </variable>

      <if test="empty($constraints)">
         <call-template name="s:phase4-main">
            <with-param name="pattern" select="$result"/>
         </call-template>
      </if>
   </template>

   <template match="rng:define[count(*) gt 1] | rng:oneOrMore[count(*) gt 1] | rng:list[count(*) gt 1]" mode="s:phase3">
      <!--
         4.12 A define, oneOrMore, zeroOrMore, optional, list or mixed element is transformed so that it has exactly one child element. If it has more than one child element, then its child elements are wrapped in a group element.
      -->
      <copy>
         <apply-templates select="@*" mode="#current"/>

         <variable name="group" as="element()">
            <element name="group" namespace="{$s:rng-ns}">
               <sequence select="*"/>
            </element>
         </variable>

         <apply-templates select="$group" mode="#current"/>

      </copy>
   </template>

   <template match="rng:element[count(*) gt 2]" mode="s:phase3">
      <!--
         4.12 Similarly, an element element is transformed so that it has exactly two child elements, the first being a name class and the second being a pattern. If it has more than two child elements, then the child elements other than the first are wrapped in a group element.
      -->
      <copy>
         <apply-templates select="@*, *[1]" mode="#current"/>

         <variable name="group" as="element()">
            <element name="group" namespace="{$s:rng-ns}">
               <sequence select="*[position() gt 1]"/>
            </element>
         </variable>

         <apply-templates select="$group" mode="#current"/>
      </copy>
   </template>

   <template match="rng:attribute[count(*) eq 1]" mode="s:phase3">
      <!--
         4.12 If an attribute element has only one child element (a name class), then a text element is added.
      -->
      <copy>
         <apply-templates select="@*, node()" mode="#current"/>
         <element name="text" namespace="{$s:rng-ns}"/>
      </copy>
   </template>

   <template match="rng:mixed" mode="s:phase3">
      <!--
         4.13 A mixed element is transformed into an interleaving with a text element.
      -->
      <element name="interleave" namespace="{$s:rng-ns}">
         <choose>
            <when test="count(*) gt 1">
               <!--
                  4.12 A define, oneOrMore, zeroOrMore, optional, list or mixed element is transformed so that it has exactly one child element. If it has more than one child element, then its child elements are wrapped in a group element.
               -->
               <variable name="group" as="element()">
                  <element name="group" namespace="{$s:rng-ns}">
                     <sequence select="*"/>
                  </element>
               </variable>

               <apply-templates select="$group" mode="#current"/>
            </when>
            <otherwise>
               <apply-templates mode="#current"/>
            </otherwise>
         </choose>
         <element name="text" namespace="{$s:rng-ns}"/>
      </element>
   </template>

   <template match="rng:optional" mode="s:phase3">
      <!--
         4.14 An optional element is transformed into a choice element with one child being the child of the optional element and the other child being empty.
      -->
      <element name="choice" namespace="{$s:rng-ns}">
         <choose>
            <when test="count(*) gt 1">
               <!--
                  4.12 A define, oneOrMore, zeroOrMore, optional, list or mixed element is transformed so that it has exactly one child element. If it has more than one child element, then its child elements are wrapped in a group element.
               -->
               <variable name="group" as="element()">
                  <element name="group" namespace="{$s:rng-ns}">
                     <sequence select="*"/>
                  </element>
               </variable>
               <apply-templates select="$group" mode="#current"/>
            </when>
            <otherwise>
               <apply-templates mode="#current"/>
            </otherwise>
         </choose>
         <element name="empty" namespace="{$s:rng-ns}"/>
      </element>
   </template>

   <template match="rng:except[count(*) gt 1]" mode="s:phase3">
      <!--
         4.12 A except element is transformed so that it has exactly one child element. If it has more than one child element, then its child elements are wrapped in a choice element.
      -->
      <copy>
         <apply-templates select="@*" mode="#current"/>

         <variable name="choice" as="element()">
            <element name="choice" namespace="{$s:rng-ns}">
               <sequence select="*"/>
            </element>
         </variable>

         <apply-templates select="$choice" mode="#current"/>
      </copy>
   </template>

   <template match="rng:zeroOrMore" mode="s:phase3">
      <!--
         4.15 A zeroOrMore element is transformed into a choice element with one child being an <oneOrMore> p </oneOrMore> element and the other child being an empty element, where p is the child of the zeroOrMore element.
      -->
      <element name="choice" namespace="{$s:rng-ns}">
         <element name="oneOrMore" namespace="{$s:rng-ns}">
            <choose>
               <when test="count(*) gt 1">
                  <!--
                     4.12 A define, oneOrMore, zeroOrMore, optional, list or mixed element is transformed so that it has exactly one child element. If it has more than one child element, then its child elements are wrapped in a group element.
                  -->
                  <variable name="group" as="element()">
                     <element name="group" namespace="{$s:rng-ns}">
                        <sequence select="*"/>
                     </element>
                  </variable>

                  <apply-templates select="$group" mode="#current"/>
               </when>
               <otherwise>
                  <apply-templates mode="#current"/>
               </otherwise>
            </choose>
         </element>
         <element name="empty" namespace="{$s:rng-ns}"/>
      </element>
   </template>

   <template match="rng:choice[count(*) eq 1] | rng:group[count(*) eq 1] | rng:interleave[count(*) eq 1]" mode="s:phase3">
      <!--
         4.12 A choice, group or interleave element is transformed so that it has exactly two child elements. If it has one child element, then it is replaced by its child element.
      -->
      <apply-templates mode="#current"/>
   </template>

   <template match="rng:choice[count(*) gt 2] | rng:group[count(*) gt 2] | rng:interleave[count(*) gt 2]" mode="s:phase3">
      <!--
         4.12 A choice, group or interleave element is transformed so that it has exactly two child elements. If it has one child element, then it is replaced by its child element. If it has more than two child elements, then the first two child elements are combined into a new element with the same name as the parent element and with the first two child elements as its children.
      -->
      <variable name="copy" as="element()">
         <copy>
            <copy-of select="@*"/>
            <element name="{local-name()}" namespace="{$s:rng-ns}">
               <sequence select="*[position() = (1, 2)]"/>
            </element>
            <sequence select="*[position() gt 2]"/>
         </copy>
      </variable>
      <!--
         The transformation is applied repeatedly until there are exactly two child elements.
      -->
      <apply-templates select="$copy" mode="#current"/>
   </template>

   <template match="text()" mode="s:phase3-constraints"/>

   <template match="rng:anyName/rng:except//rng:anyName" mode="s:phase3-constraints">
      <!--
         4.16
      -->
      <sequence select="error($f:error-code, f:error-message(., 'An except element that is a child of an anyName element must not have any anyName descendant elements.'))"/>
   </template>

   <template match="rng:nsName/rng:except//rng:nsName | rng:nsName/rng:except//rng:anyName" mode="s:phase3-constraints">
      <!--
         4.16
      -->
      <sequence select="error($f:error-code, f:error-message(., 'An except element that is a child of an nsName element must not have any nsName or anyName descendant elements.'))"/>
   </template>

   <template match="rng:attribute/rng:name[empty(preceding-sibling::rng:*) and @ns = '' and text() = 'xmlns']
      | rng:attribute/rng:*[1]//rng:name[@ns = '' and text() = 'xmlns']" mode="s:phase3-constraints">
      <!--
         4.16
      -->
      <sequence select="error($f:error-code, f:error-message(., 'A name element that occurs as the first child of an attribute element or as the descendant of the first child of an attribute element and that has an ns attribute with value equal to the empty string must not have content equal to xmlns.'))"/>
   </template>

   <template match="rng:attribute/rng:name[empty(preceding-sibling::rng:*) and @ns = 'http://www.w3.org/2000/xmlns']
      | rng:attribute/rng:*[1]//rng:name[@ns = 'http://www.w3.org/2000/xmlns']
      | rng:attribute/rng:nsName[empty(preceding-sibling::rng:*) and @ns = 'http://www.w3.org/2000/xmlns']
      | rng:attribute/rng:*[1]//rng:nsName[@ns = 'http://www.w3.org/2000/xmlns']" mode="s:phase3-constraints">
      <!--
         4.16
      -->
      <sequence select="error($f:error-code, f:error-message(., 'A name or nsName element that occurs as the first child of an attribute element or as the descendant of the first child of an attribute element must not have an ns attribute with value http://www.w3.org/2000/xmlns.'))"/>
   </template>

   <template match="rng:value[@datatypeLibrary = '' and not(@type = ('token', 'string'))]
      | rng:data[@datatypeLibrary = '' and not(@type = ('token', 'string'))]" mode="s:phase3-constraints">
      <!--
         4.16
      -->
      <sequence select="error($f:error-code, f:error-message(., 'The type attribute must identify a datatype within the datatype library identified by the value of the datatypeLibrary attribute.'))"/>
   </template>

   <template match="rng:data[@datatypeLibrary = '' and rng:param]" mode="s:phase3-constraints">
      <!--
         4.16
      -->
      <sequence select="error($f:error-code, f:error-message(., 'Types in the built-in datatype library do not accept any parameters.'))"/>
   </template>

   <!--
      ## Phase 4: define/start combining
   -->

   <template name="s:phase4-main">
      <param name="pattern" as="node()"/>

      <variable name="result" as="node()">
         <apply-templates select="$pattern" mode="s:phase4"/>
      </variable>

      <call-template name="s:phase5-main">
         <with-param name="pattern" select="$result"/>
      </call-template>
   </template>

   <template match="rng:grammar" mode="s:phase4">

      <copy>
         <apply-templates select="@*" mode="#current"/>
         <!--
            4.17 For each grammar element, all define elements with the same name are combined together.
         -->
         <for-each-group select="rng:define" group-by="@name">
            <choose>
               <when test="count(current-group()) eq 1">
                  <apply-templates select="current-group()" mode="#current"/>
               </when>
               <otherwise>
                  <variable name="combine" select="distinct-values(current-group()/@combine/string())"/>

                  <if test="count(current-group()[not(@combine)]) gt 1">
                     <sequence select="error($f:error-code, f:error-message(., 'For any name, there must not be more than one define element with that name that does not have a combine attribute.'))"/>
                  </if>

                  <if test="count($combine) gt 1">
                     <sequence select="error($f:error-code, f:error-message(., 'For any name, if there is a define element with that name that has a combine attribute with the value choice, then there must not also be a define element with that name that has a combine attribute with the value interleave.'))"/>
                  </if>

                  <variable name="define" as="element()">
                     <element name="define" namespace="{$s:rng-ns}">
                        <attribute name="name" select="current-grouping-key()"/>
                        <element name="{$combine}" namespace="{$s:rng-ns}">
                           <sequence select="current-group()[position() = (1, 2)]/node()"/>
                        </element>
                        <sequence select="current-group()[position() gt 2]"/>
                     </element>
                  </variable>
                  <apply-templates select="$define" mode="s:phase4-combine"/>
               </otherwise>
            </choose>
         </for-each-group>
         <!--
            4.17 Similarly, for each grammar element all start elements are combined together.
         -->
         <choose>
            <when test="count(rng:start) le 1">
               <apply-templates select="rng:start" mode="#current"/>
            </when>
            <otherwise>
               <variable name="combine" select="distinct-values(rng:start/@combine/string())"/>

               <if test="count(rng:start[not(@combine)]) gt 1">
                  <sequence select="error($f:error-code, f:error-message(., 'There must not be more than one start element that does not have a combine attribute.'))"/>
               </if>

               <if test="count($combine) gt 1">
                  <sequence select="error($f:error-code, f:error-message(., 'If there is a start element that has a combine attribute with the value choice, there must not also be a start element that has a combine attribute with the value interleave.'))"/>
               </if>

               <variable name="start" as="element()">
                  <element name="start" namespace="{$s:rng-ns}">
                     <element name="{$combine}" namespace="{$s:rng-ns}">
                        <sequence select="rng:start[position() = (1, 2)]/node()"/>
                     </element>
                     <sequence select="rng:start[position() gt 2]"/>
                  </element>
               </variable>
               <apply-templates select="$start" mode="s:phase4-combine"/>
            </otherwise>
         </choose>

         <apply-templates select="* except (rng:define, rng:start)" mode="#current"/>
      </copy>
   </template>

   <template match="rng:define[not(rng:define)] | rng:start[not(rng:start)]" mode="s:phase4-combine">
      <apply-templates select="." mode="s:phase4"/>
   </template>

   <template match="rng:define[rng:define] | rng:start[rng:start]" mode="s:phase4-combine">

      <variable name="copy" as="element()">
         <copy>
            <copy-of select="@*"/>
            <element name="{*[1]/local-name()}" namespace="{$s:rng-ns}">
               <sequence select="*[1], *[2]/node()"/>
            </element>
            <sequence select="*[position() gt 2]"/>
         </copy>
      </variable>

      <apply-templates select="$copy" mode="#current"/>
   </template>

   <!--
      ## Phase 5: Grammars simplification
   -->

   <template name="s:phase5-main">
      <param name="pattern" as="node()"/>

      <variable name="result" as="node()">
         <apply-templates select="$pattern" mode="s:phase5"/>
      </variable>

      <call-template name="s:phase6-main">
         <with-param name="pattern" select="$result"/>
      </call-template>
   </template>

   <template match="/" mode="s:phase5">

      <document>
         <!--
            4.18 First, transform the top-level pattern p into <grammar><start>p</start></grammar>.
         -->
         <element name="grammar" namespace="{$s:rng-ns}">
            <element name="start" namespace="{$s:rng-ns}">
               <apply-templates select="rng:*" mode="s:phase5">
                  <with-param name="ignore-define" select="true()" tunnel="yes"/>
               </apply-templates>
            </element>
            <!--
               4.18 Move all define elements to be children of the top-level grammar element.
            -->
            <apply-templates select="descendant::rng:define" mode="s:phase5"/>
         </element>
      </document>
   </template>

   <template match="rng:define" mode="s:phase5">
      <param name="ignore-define" tunnel="yes"/>

      <if test="not($ignore-define)">
         <copy>
            <!--
               4.18 Rename define elements so that no two define elements anywhere in the schema have the same name.
            -->
            <attribute name="name" select="s:phase5-define-name(.)"/>
            <apply-templates select="@* except @name, node()" mode="#current"/>
         </copy>
      </if>
   </template>

   <template match="rng:grammar" mode="s:phase5">

      <if test="not(rng:start)">
         <sequence select="error($f:error-code, f:error-message(., 'A grammar must have a start child element.'))"/>
      </if>

      <!--
         4.18 Replace each nested grammar element by the child of its start element.
      -->
      <apply-templates select="rng:start/node()" mode="#current"/>
   </template>

   <template match="rng:ref/@name" mode="s:phase5">

      <variable name="define" select="ancestor::rng:grammar[1]/rng:define[@name=current()]"/>

      <if test="not($define)">
         <sequence select="error($f:error-code, f:error-message(., 'Every ref element must refer to a define element.'))"/>
      </if>

      <!--
         4.18 To rename a define element, change the value of its name attribute and change the value of the name attribute of all ref and parentRef elements that refer to that define element.
      -->
      <attribute name="name" select="$define/s:phase5-define-name(.)"/>
   </template>

   <template match="rng:parentRef" mode="s:phase5">
      <!--
         4.18 Rename each parentRef element to ref.
      -->
      <element name="ref" namespace="{$s:rng-ns}">
         <apply-templates select="@*, node()" mode="#current"/>
      </element>
   </template>

   <template match="rng:parentRef/@name" mode="s:phase5">

      <variable name="define" select="ancestor::rng:grammar[2]/rng:define[@name=current()]"/>

      <if test="not($define)">
         <sequence select="error($f:error-code, f:error-message(., 'Every parentRef element must refer to a define element.'))"/>
      </if>

      <!--
         4.18 To rename a define element, change the value of its name attribute and change the value of the name attribute of all ref and parentRef elements that refer to that define element.
      -->
      <attribute name="name" select="$define/s:phase5-define-name(.)"/>
   </template>

   <function name="s:phase5-define-name">
      <param name="define" as="element(rng:define)"/>
      <sequence select="concat($define/@name, '_', generate-id($define))"/>
   </function>

   <!--
      ## Phase 6: Move elements to define
   -->

   <template name="s:phase6-main">
      <param name="pattern" as="node()"/>

      <variable name="result" as="node()">
         <apply-templates select="$pattern" mode="s:phase6"/>
      </variable>

      <call-template name="s:phase7-main">
         <with-param name="pattern" select="$result"/>
      </call-template>
   </template>

   <template match="rng:grammar" mode="s:phase6">
      <!--
         4.19 Now, for each element element that is not the child of a define element, add a define element to the grammar element, and replace the element element by a ref element referring to the added define element. The child of the added define element is the element element.
      -->
      <copy>
         <apply-templates select="@*, node()" mode="#current"/>

         <for-each select=".//rng:element[not(parent::rng:define)]">
            <element name="define" namespace="{$s:rng-ns}">
               <attribute name="name" select="s:phase6-define-name(.)"/>
               <element name="element" namespace="{$s:rng-ns}">
                  <apply-templates select="@*, node()" mode="#current"/>
               </element>
            </element>
         </for-each>
      </copy>
   </template>

   <template match="rng:define" mode="s:phase6">
      <!--
         4.19 First, remove any define element that is not reachable. 
      -->
      <if test="root()//rng:ref[@name=current()/@name]">
         <next-match/>
      </if>
   </template>

   <template match="rng:define[not(rng:element)]" mode="s:phase6">
      <!--
         4.19 Finally, remove any define element whose child is not an element element.
      -->
   </template>

   <template match="rng:element[not(parent::rng:define)]" mode="s:phase6">
      <!--
         4.19 Now, for each element element that is not the child of a define element, add a define element to the grammar element, and replace the element element by a ref element referring to the added define element.
      -->
      <element name="ref" namespace="{$s:rng-ns}">
         <attribute name="name" select="s:phase6-define-name(.)"/>
      </element>
   </template>

   <template match="rng:ref" mode="s:phase6">
      <param name="defs" as="element(rng:define)*" tunnel="yes"/>

      <!--
         4.19 Define a ref element to be expandable if it refers to a define element whose child is not an element element. For each ref element that is expandable and is a descendant of a start element or an element element, expand it by replacing the ref element by the child of the define element to which it refers and then recursively expanding any expandable ref elements in this replacement.
      -->
      <variable name="define" select="ancestor::rng:grammar/rng:define[@name=current()/@name]"/>

      <choose>
         <when test="not($define/rng:element)">

            <if test="some $d in $defs satisfies $d is $define">
               <sequence select="error($f:error-code, f:error-message(., 'Circular reference.'))"/>
            </if>

            <apply-templates select="$define/node()" mode="#current">
               <with-param name="defs" select="$defs, $define" tunnel="yes"/>
            </apply-templates>
         </when>
         <otherwise>
            <next-match/>
         </otherwise>
      </choose>
   </template>

   <function name="s:phase6-define-name">
      <param name="element" as="element(rng:element)"/>
      <sequence select="
         if ($element/rng:name) then concat($element/rng:name[1], '_', generate-id($element))
         else generate-id($element)
      "/>
   </function>

   <!--
      ## Phase 7: notAllowed simplification
   -->

   <template name="s:phase7-main">
      <param name="pattern" as="node()"/>

      <variable name="result" as="node()">
         <apply-templates select="$pattern" mode="s:phase7"/>
      </variable>

      <call-template name="s:phase8-main">
         <with-param name="pattern" select="$result"/>
      </call-template>
   </template>

   <template match="rng:grammar" mode="s:phase7">

      <variable name="copy" as="element()">
         <copy>
            <apply-templates select="@*, node()" mode="#current"/>
         </copy>
      </variable>

      <choose>
         <!--
            4.20 In this rule, the grammar is transformed so that a notAllowed element occurs only as the child of a start or element element.
         -->
         <when test="$copy//rng:notAllowed[not(parent::rng:start or parent::rng:element)]">
            <apply-templates select="$copy" mode="#current"/>
         </when>
         <otherwise>
            <sequence select="$copy"/>
         </otherwise>
      </choose>
   </template>

   <template match="rng:attribute[rng:notAllowed] | rng:list[rng:notAllowed] | rng:group[rng:notAllowed] | rng:interleave[rng:notAllowed] | rng:oneOrMore[rng:notAllowed]" mode="s:phase7">
      <!--
         4.20 An attribute, list, group, interleave, or oneOrMore element that has a notAllowed child element is transformed into a notAllowed element.
      -->
      <element name="notAllowed" namespace="{$s:rng-ns}"/>
   </template>

   <template match="rng:choice[every $child in * satisfies $child[self::rng:notAllowed]]" mode="s:phase7">
      <!--
         4.20 A choice element that has two notAllowed child elements is transformed into a notAllowed element. 
      -->
      <element name="notAllowed" namespace="{$s:rng-ns}"/>
   </template>

   <template match="rng:choice[rng:notAllowed and *[not(self::rng:notAllowed)]]" mode="s:phase7">
      <!--
         4.20 A choice element that has one notAllowed child element is transformed into its other child element.
      -->
      <apply-templates select="*[not(self::rng:notAllowed)]" mode="#current"/>
   </template>

   <template match="rng:except[rng:notAllowed]" mode="s:phase7">
      <!--
         4.20 An except element that has a notAllowed child element is removed.
      -->
   </template>

   <!--
      ## Phase 8: empty simplification
   -->

   <template name="s:phase8-main">
      <param name="pattern" as="node()"/>

      <variable name="result" as="node()">
         <apply-templates select="$pattern" mode="s:phase8"/>
      </variable>

      <variable name="errors" as="item()*">
         <apply-templates select="$result" mode="s:prohibited-path"/>
      </variable>

      <sequence select="$result[empty($errors)]"/>
   </template>

   <template match="rng:grammar" mode="s:phase8">

      <variable name="copy" as="element()">
         <copy>
            <apply-templates select="@*, node()" mode="#current"/>
         </copy>
      </variable>

      <choose>
         <!--
            4.21 In this rule, the grammar is transformed so that an empty element does not occur as a child of a group, interleave, or oneOrMore element or as the second child of a choice element.
         -->
         <when test="$copy//rng:empty[
            parent::rng:group 
            or parent::rng:interleave 
            or parent::rng:oneOrMore 
            or (parent::rng:choice and . is ../*[2])]">
            <apply-templates select="$copy" mode="#current"/>
         </when>
         <otherwise>
            <sequence select="$copy"/>
         </otherwise>
      </choose>
   </template>

   <template match="rng:*[(self::rng:group or self::rng:interleave or self::rng:choice) and count(rng:empty) gt 1]" mode="s:phase8">
      <!--
         4.21 A group, interleave or choice element that has two empty child elements is transformed into an empty element.
      -->
      <element name="empty" namespace="{$s:rng-ns}"/>
   </template>

   <template match="rng:*[(self::rng:group or self::rng:interleave) and count(rng:empty) eq 1]" mode="s:phase8">
      <!--
         4.21 A group or interleave element that has one empty child element is transformed into its other child element.
      -->
      <apply-templates select="*[not(self::rng:empty)]" mode="#current"/>
   </template>

   <template match="rng:choice[*[1][not(self::rng:empty)] and *[2][self::rng:empty]]" mode="s:phase8">
      <!--
         4.21 A choice element whose second child element is an empty element is transformed by interchanging its two child elements.
      -->
      <copy>
         <apply-templates select="@*, *[2], *[1]" mode="#current"/>
      </copy>
   </template>

   <template match="rng:oneOrMore[rng:empty]" mode="s:phase8">
      <!--
         4.21 A oneOrMore element that has an empty child element is transformed into an empty element.
      -->
      <element name="empty" namespace="{$s:rng-ns}"/>
   </template>

   <!--
      ## Restrictions
   -->

   <template match="text()" mode="s:prohibited-path"/>

   <template match="rng:attribute//rng:ref" mode="s:prohibited-path">
      <sequence select="s:prohibited-path-error(., 'attribute//ref')"/>
   </template>

   <template match="rng:attribute//rng:attribute" mode="s:prohibited-path">
      <sequence select="s:prohibited-path-error(., 'attribute//attribute')"/>
   </template>

   <template match="rng:oneOrMore//rng:group//rng:attribute" mode="s:prohibited-path">
      <sequence select="s:prohibited-path-error(., 'oneOrMore//group//attribute')"/>
   </template>

   <template match="rng:oneOrMore//rng:interleave//rng:attribute" mode="s:prohibited-path">
      <sequence select="s:prohibited-path-error(., 'oneOrMore//interleave//attribute')"/>
   </template>

   <template match="rng:list//rng:list" mode="s:prohibited-path">
      <sequence select="s:prohibited-path-error(., 'list//list')"/>
   </template>

   <template match="rng:list//rng:ref" mode="s:prohibited-path">
      <sequence select="s:prohibited-path-error(., 'list//ref')"/>
   </template>

   <template match="rng:list//rng:attribute" mode="s:prohibited-path">
      <sequence select="s:prohibited-path-error(., 'list//attribute')"/>
   </template>

   <template match="rng:list//rng:text" mode="s:prohibited-path">
      <sequence select="s:prohibited-path-error(., 'list//text')"/>
   </template>

   <template match="rng:list//rng:interleave" mode="s:prohibited-path">
      <sequence select="s:prohibited-path-error(., 'list//interleave')"/>
   </template>

   <template match="rng:data/rng:except//rng:attribute" mode="s:prohibited-path">
      <sequence select="s:prohibited-path-error(., 'data/except//attribute')"/>
   </template>

   <template match="rng:data/rng:except//rng:ref" mode="s:prohibited-path">
      <sequence select="s:prohibited-path-error(., 'data/except//ref')"/>
   </template>

   <template match="rng:data/rng:except//rng:text" mode="s:prohibited-path">
      <sequence select="s:prohibited-path-error(., 'data/except//text')"/>
   </template>

   <template match="rng:data/rng:except//rng:list" mode="s:prohibited-path">
      <sequence select="s:prohibited-path-error(., 'data/except//list')"/>
   </template>

   <template match="rng:data/rng:except//rng:group" mode="s:prohibited-path">
      <sequence select="s:prohibited-path-error(., 'data/except//group')"/>
   </template>

   <template match="rng:data/rng:except//rng:interleave" mode="s:prohibited-path">
      <sequence select="s:prohibited-path-error(., 'data/except//interleave')"/>
   </template>

   <template match="rng:data/rng:except//rng:oneOrMore" mode="s:prohibited-path">
      <sequence select="s:prohibited-path-error(., 'data/except//oneOrMore')"/>
   </template>

   <template match="rng:data/rng:except//rng:empty" mode="s:prohibited-path">
      <sequence select="s:prohibited-path-error(., 'data/except//empty')"/>
   </template>

   <template match="rng:start//rng:attribute" mode="s:prohibited-path">
      <sequence select="s:prohibited-path-error(., 'start//attribute')"/>
   </template>

   <template match="rng:start//rng:data" mode="s:prohibited-path">
      <sequence select="s:prohibited-path-error(., 'start//data')"/>
   </template>

   <template match="rng:start//rng:value" mode="s:prohibited-path">
      <sequence select="s:prohibited-path-error(., 'start//value')"/>
   </template>

   <template match="rng:start//rng:text" mode="s:prohibited-path">
      <sequence select="s:prohibited-path-error(., 'start//text')"/>
   </template>

   <template match="rng:start//rng:list" mode="s:prohibited-path">
      <sequence select="s:prohibited-path-error(., 'start//list')"/>
   </template>

   <template match="rng:start//rng:group" mode="s:prohibited-path">
      <sequence select="s:prohibited-path-error(., 'start//group')"/>
   </template>

   <template match="rng:start//rng:interleave" mode="s:prohibited-path">
      <sequence select="s:prohibited-path-error(., 'start//interleave')"/>
   </template>

   <template match="rng:start//rng:oneOrMore" mode="s:prohibited-path">
      <sequence select="s:prohibited-path-error(., 'start//oneOrMore')"/>
   </template>

   <template match="rng:start//rng:empty" mode="s:prohibited-path">
      <sequence select="s:prohibited-path-error(., 'start//empty')"/>
   </template>

   <function name="s:prohibited-path-error">
      <param name="n" as="node()"/>
      <param name="path"/>

      <sequence select="error($f:error-code, f:error-message($n, concat('The path ', $path, ' is prohibited.')))"/>
   </function>

</stylesheet>
