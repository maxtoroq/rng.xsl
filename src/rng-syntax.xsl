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
   xmlns:f="http://maxtoroq.github.io/rng.xsl/syntax">

   <variable name="f:rng-ns" select="'http://relaxng.org/ns/structure/1.0'"/>
   <variable name="f:error-code" select="QName('http://maxtoroq.github.io/rng.xsl', 'rng.xsl:invalid-syntax')"/>

   <function name="f:error-message" as="xs:string">
      <param name="n" as="node()"/>
      <param name="message" as="xs:string"/>

      <sequence select="$message"/>
   </function>

   <template match="rng:*" mode="f:pattern f:nameClass f:exceptNameClass f:param f:exceptPattern f:grammarContent f:includeContent">
      <sequence select="error($f:error-code, f:error-message(., concat('Element ', name(), ' not allowed.')))"/>
   </template>

   <template match="rng:element[not(@name)]" mode="f:pattern">

      <variable name="name-class" as="xs:boolean?">
         <apply-templates select="rng:*[1]" mode="f:nameClass"/>
      </variable>

      <variable name="patterns" as="xs:boolean*">
         <apply-templates select="rng:*[position() gt 1]" mode="f:pattern"/>
      </variable>

      <sequence select="(count(rng:*) ge 2 or error($f:error-code, f:error-message(., 'Two or more child elements expected.')))
         and f:attributes(.)
         and f:no-text(.)
         and $name-class
         and (every $p in $patterns satisfies $p)"/>
   </template>

   <template match="rng:element[@name]" mode="f:pattern">

      <variable name="patterns" as="xs:boolean*">
         <apply-templates select="rng:*" mode="f:pattern"/>
      </variable>

      <sequence select="f:one-or-more(.)
         and f:attributes(., @name)
         and f:QName(@name)
         and f:no-text(.)
         and (every $p in $patterns satisfies $p)"/>
   </template>

   <template match="rng:attribute[not(@name)]" mode="f:pattern">

      <variable name="name-class" as="xs:boolean?">
         <apply-templates select="rng:*[1]" mode="f:nameClass"/>
      </variable>

      <variable name="pattern" as="xs:boolean?">
         <apply-templates select="rng:*[2]" mode="f:pattern"/>
      </variable>

      <sequence select="(count(rng:*) = (1, 2) or error($f:error-code, f:error-message(., 'One or two child elements expected.')))
         and f:attributes(.)
         and f:no-text(.)
         and $name-class
         and ($pattern, true())[1]"/>
   </template>

   <template match="rng:attribute[@name]" mode="f:pattern">

      <variable name="pattern" as="xs:boolean?">
         <apply-templates select="rng:*[1]" mode="f:pattern"/>
      </variable>

      <sequence select="f:zero-or-one(.)
         and f:attributes(., @name)
         and f:QName(@name)
         and f:no-text(.)
         and ($pattern, true())[1]"/>
   </template>

   <template match="rng:group | rng:interleave | rng:choice | rng:optional | rng:zeroOrMore | rng:oneOrMore | rng:list | rng:mixed" mode="f:pattern">

      <variable name="patterns" as="xs:boolean*">
         <apply-templates select="rng:*" mode="f:pattern"/>
      </variable>

      <sequence select="f:one-or-more(.)
         and f:attributes(.)
         and f:no-text(.)
         and (every $p in $patterns satisfies $p)"/>
   </template>

   <template match="rng:empty | rng:text | rng:notAllowed" mode="f:pattern">

      <sequence select="f:attributes(.)
         and f:no-children(.)
         and f:no-text(.)"/>
   </template>

   <template match="rng:ref | rng:parentRef" mode="f:pattern">

      <sequence select="f:attributes(., @name, 'name')
         and f:NCName(@name)
         and f:no-children(.)
         and f:no-text(.)"/>
   </template>

   <template match="rng:externalRef" mode="f:pattern">

      <sequence select="f:attributes(., @href, 'href')
         and f:no-children(.)
         and f:no-text(.)"/>
   </template>

   <template match="rng:value" mode="f:pattern">

      <sequence select="f:no-children(., false())
         and f:attributes(., @type)
         and (empty(@type) or f:NCName(@type))"/>
   </template>

   <template match="rng:data" mode="f:pattern">

      <variable name="params" as="xs:boolean*">
         <apply-templates select="rng:param" mode="f:param"/>
      </variable>

      <variable name="except" as="xs:boolean?">
         <apply-templates select="rng:*[position() eq last() and not(self::rng:param)]" mode="f:exceptPattern"/>
      </variable>

      <sequence select="(empty(rng:* except (rng:param, rng:except)) or error($f:error-code, f:error-message(., 'Only rng:param and rng:except children allowed.')))
         and (count(rng:except) le 1 or error($f:error-code, f:error-message(., 'At most one rng:except child is allowed.')))
         and f:attributes(., @type, 'type')
         and f:NCName(@type)
         and f:no-text(.)
         and (every $p in $params satisfies $p)
         and ($except, true())[1]"/>
   </template>

   <template match="rng:grammar" mode="f:pattern">

      <variable name="content" as="xs:boolean*">
         <apply-templates select="rng:*" mode="f:grammarContent"/>
      </variable>

      <sequence select="f:attributes(.)
         and f:no-text(.)
         and (every $c in $content satisfies $c)"/>
   </template>

   <template match="rng:param" mode="f:param">

      <sequence select="f:attributes(., @name, 'name')
         and f:NCName(@name)
         and f:no-children(., false())"/>
   </template>

   <template match="rng:except" mode="f:exceptPattern">

      <variable name="patterns" as="xs:boolean*">
         <apply-templates select="rng:*" mode="f:pattern"/>
      </variable>

      <sequence select="f:one-or-more(.)
         and f:attributes(.)
         and f:no-text(.)
         and (every $p in $patterns satisfies $p)"/>
   </template>

   <template match="rng:start" mode="f:grammarContent f:includeContent">

      <variable name="pattern" as="xs:boolean?">
         <apply-templates select="rng:*[1]" mode="f:pattern"/>
      </variable>

      <sequence select="f:exactly-one(.)
         and f:attributes(., @combine)
         and (empty(@combine) or f:method(@combine))
         and f:no-text(.)
         and $pattern"/>
   </template>

   <template match="rng:define" mode="f:grammarContent f:includeContent">

      <variable name="patterns" as="xs:boolean*">
         <apply-templates select="rng:*" mode="f:pattern"/>
      </variable>

      <sequence select="f:one-or-more(.)
         and f:attributes(., (@name, @combine), 'name')
         and f:NCName(@name)
         and (empty(@combine) or f:method(@combine))
         and f:no-text(.)
         and (every $p in $patterns satisfies $p)"/>
   </template>

   <template match="rng:div" mode="f:grammarContent f:includeContent">

      <variable name="content" as="xs:boolean*">
         <apply-templates select="rng:*" mode="#current"/>
      </variable>

      <sequence select="f:attributes(.)
         and f:no-text(.)
         and (every $c in $content satisfies $c)"/>
   </template>

   <template match="rng:include" mode="f:grammarContent">

      <variable name="content" as="xs:boolean*">
         <apply-templates select="rng:*" mode="f:includeContent"/>
      </variable>

      <sequence select="f:attributes(., @href, 'href')
         and f:no-text(.)
         and (every $c in $content satisfies $c)"/>
   </template>

   <template match="rng:name" mode="f:nameClass">

      <sequence select="f:attributes(.)
         and f:no-children(., false())
         and f:text(.)
         and f:QName(text())"/>
   </template>

   <template match="rng:anyName | rng:nsName" mode="f:nameClass">

      <variable name="pattern" as="xs:boolean?">
         <apply-templates select="rng:*[1]" mode="f:exceptNameClass"/>
      </variable>

      <sequence select="f:zero-or-one(.)
         and f:attributes(.)
         and f:no-text(.)
         and ($pattern, true())[1]"/>
   </template>

   <template match="rng:choice" mode="f:nameClass">

      <variable name="patterns" as="xs:boolean*">
         <apply-templates select="rng:*" mode="f:nameClass"/>
      </variable>

      <sequence select="f:one-or-more(.)  
         and f:attributes(.)
         and f:no-text(.)
         and (every $p in $patterns satisfies $p)"/>
   </template>

   <template match="rng:except" mode="f:exceptNameClass">

      <variable name="patterns" as="xs:boolean*">
         <apply-templates select="rng:*" mode="f:nameClass"/>
      </variable>

      <sequence select="f:one-or-more(.) 
         and f:attributes(.)
         and f:no-text(.)
         and (every $p in $patterns satisfies $p)"/>
   </template>

   <!--
      Helpers
   -->

   <function name="f:no-children" as="xs:boolean">
      <param name="el" as="element()"/>

      <sequence select="f:no-children($el, true())"/>
   </function>

   <function name="f:no-children" as="xs:boolean">
      <param name="el" as="element()"/>
      <param name="allow-foreign" as="xs:boolean"/>

      <sequence select="
         (empty($el/rng:*)
            and ($allow-foreign 
               or empty($el/*[not(self::rng:*)])
            )
         )     
         or error($f:error-code, f:error-message($el, 'Child elements are not allowed.'))"/>
   </function>

   <function name="f:zero-or-one" as="xs:boolean">
      <param name="el" as="element()"/>

      <sequence select="count($el/rng:*) le 1
         or error($f:error-code, f:error-message($el, 'Zero or one child element is expected.'))"/>
   </function>

   <function name="f:exactly-one" as="xs:boolean">
      <param name="el" as="element()"/>

      <sequence select="count($el/rng:*) eq 1
         or error($f:error-code, f:error-message($el, 'One child element is expected.'))"/>
   </function>

   <function name="f:one-or-more" as="xs:boolean">
      <param name="el" as="element()"/>

      <sequence select="count($el/rng:*) ge 1
         or error($f:error-code, f:error-message($el, 'One or more child elements are expected.'))"/>
   </function>

   <function name="f:no-text" as="xs:boolean">
      <param name="el" as="element()"/>

      <sequence select="empty($el/text()[normalize-space()])
         or error($f:error-code, f:error-message($el, 'Text is not allowed.'))"/>
   </function>

   <function name="f:text" as="xs:boolean">
      <param name="el" as="element()"/>

      <sequence select="$el/text()
         or error($f:error-code, f:error-message($el, 'Text is expected.'))"/>
   </function>

   <function name="f:attributes" as="xs:boolean">
      <param name="el" as="element()"/>

      <sequence select="f:attributes($el, ())"/>
   </function>

   <function name="f:attributes" as="xs:boolean">
      <param name="el" as="element()"/>
      <param name="allowed" as="attribute()*"/>

      <sequence select="f:attributes($el, $allowed, ())"/>
   </function>

   <function name="f:attributes" as="xs:boolean">
      <param name="el" as="element()"/>
      <param name="allowed" as="attribute()*"/>
      <param name="required" as="xs:string*"/>

      <variable name="attribs" select="$el/@*"/>

      <variable name="unexpected" select="
         $attribs[not(namespace-uri()) or (namespace-uri() eq $f:rng-ns)] 
            except ($attribs[self::attribute(ns)], $attribs[self::attribute(datatypeLibrary)]/f:datatypeLibrary(.), $allowed)"/>

      <variable name="expected" select="$attribs[name() = $required]"/>
      <variable name="missing" select="$required[not(. = $expected/name())]"/>

      <sequence select="
         if (not(empty($unexpected))) then 
            error($f:error-code, f:error-message($el, concat('Attribute ', $unexpected[1]/name(), ' is not allowed.')))
         else if (count($required) ne count($expected)) then
            error($f:error-code, f:error-message($el, concat('Attribute ', $missing[1], ' is expected.')))
         else true()"/>
   </function>

   <function name="f:datatypeLibrary">
      <param name="datatypeLibrary" as="node()"/>
      <!--
         3 The value of the datatypeLibrary attribute must match the anyURI symbol as described in the previous paragraph; in addition, it must not use the relative form of URI reference and must not have a fragment identifier
      -->
      <sequence select="if (contains($datatypeLibrary, '#')) then 
         error($f:error-code, f:error-message($datatypeLibrary, 'The datatypeLibrary attribute must not include a fragment identifier.')) 
         else $datatypeLibrary"/>
   </function>

   <function name="f:NCName" as="xs:boolean">
      <param name="n" as="node()"/>

      <sequence select="string($n) castable as xs:QName
         or error($f:error-code, f:error-message($n, 'Node is not a valid NCName.'))"/>
   </function>

   <function name="f:QName" as="xs:boolean">
      <param name="n" as="node()"/>

      <variable name="prefix" select="substring-before($n, ':')"/>
      <variable name="local" select="(substring-after($n, ':')[$prefix], string($n))[1]"/>

      <sequence select="
         ((not($prefix) or namespace-uri-for-prefix($prefix, $n/ancestor-or-self::*[1]))
            and $local castable as xs:QName)
         or error($f:error-code, f:error-message($n, concat(string($n), ' is not a valid QName.')))"/>
   </function>

   <function name="f:method" as="xs:boolean">
      <param name="n" as="node()"/>

      <sequence select="normalize-space($n) = ('choice', 'interleave')
         or error($f:error-code, f:error-message($n, 'Invalid method.'))"/>
   </function>

</stylesheet>
