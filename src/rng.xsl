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
   xmlns:s="http://maxtoroq.github.io/rng.xsl/simplify"
   xpath-default-namespace="http://relaxng.org/ns/structure/1.0">

   <import href="rng-simplify.xsl"/>
   <include href="rng-xsd.xsl"/>

   <param name="r:schema" as="document-node()?"/>

   <key name="r:define" match="define" use="@name"/>

   <template match="/ | @* | node()" mode="r:main" name="r:main">
      <param name="schema" select="$r:schema" as="document-node()"/>
      <param name="instance" select="." as="node()"/>

      <variable name="simplified" as="node()">
         <apply-templates select="$schema" mode="s:main"/>
      </variable>

      <variable name="validated" as="item()+">
         <apply-templates select="$simplified" mode="r:ol">
            <with-param name="nodes" select="
               if ($instance instance of document-node()) then 
               exactly-one($instance/*) else $instance"/>
         </apply-templates>
      </variable>

      <sequence select="$validated[1]"/>
   </template>

   <template match="*" mode="r:li">
      <message select="'li template is not defined for:'"/>
      <message select="." terminate="yes"/>
   </template>

   <template match="grammar" mode="r:ol">
      <param name="nodes" as="node()*"/>

      <apply-templates select="start/*" mode="#current">
         <with-param name="nodes" select="$nodes"/>
      </apply-templates>
   </template>

   <template match="ref" mode="r:ol r:ul">
      <param name="nodes" as="node()*"/>

      <variable name="define" select="key('r:define', @name)"/>

      <apply-templates select="$define/element" mode="#current">
         <with-param name="nodes" select="$nodes"/>
      </apply-templates>
   </template>

   <template match="element" mode="r:ol">
      <param name="nodes" as="node()*"/>

      <variable name="relevant-nodes" select="$nodes[not(self::attribute())]"/>

      <variable name="first-match" as="node()?">
         <call-template name="r:first-match-ordered">
            <with-param name="nodes" select="$relevant-nodes"/>
         </call-template>
      </variable>

      <sequence select="not(empty($first-match)), $first-match"/>
   </template>

   <template match="element" mode="r:ul">
      <param name="nodes" as="node()*"/>

      <variable name="relevant-nodes" select="$nodes[not(self::attribute())]"/>

      <variable name="first-match" as="node()?">
         <call-template name="r:first-match-unordered">
            <with-param name="nodes" select="$relevant-nodes"/>
         </call-template>
      </variable>

      <sequence select="not(empty($first-match)), $first-match"/>
   </template>

   <template match="element" mode="r:li">
      <param name="n" as="node()"/>

      <choose>
         <when test="$n instance of element()">
            <variable name="name-matches" as="xs:boolean">
               <apply-templates select="*[1]" mode="#current">
                  <with-param name="n" select="$n"/>
               </apply-templates>
            </variable>
            <choose>
               <when test="$name-matches">
                  <variable name="content" as="node()*">
                     <sequence select="$n/@*"/>
                     <choose>
                        <when test="every $child in $n/node() satisfies $child instance of text()">
                           <sequence select="$n/node()"/>
                        </when>
                        <otherwise>
                           <for-each-group select="$n/node()[self::element() or self::text()[normalize-space()]]" group-adjacent="boolean(self::text())">
                              <choose>
                                 <when test="self::element() or count(current-group()) eq 1">
                                    <sequence select="current-group()"/>
                                 </when>
                                 <otherwise>
                                    <value-of select="string-join(current-group(), '')"/>
                                 </otherwise>
                              </choose>
                           </for-each-group>
                        </otherwise>
                     </choose>
                  </variable>
                  <variable name="matching-content" as="item()+">
                     <apply-templates select="*[2]" mode="r:ol">
                        <with-param name="nodes" select="$content"/>
                     </apply-templates>
                  </variable>
                  <sequence select="$matching-content[1]
                     and count($content) eq (count($matching-content) - 1)"/>
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

   <template match="attribute" mode="r:ol r:ul">
      <param name="nodes" as="node()*"/>

      <variable name="relevant-nodes" select="$nodes[self::attribute()]"/>

      <variable name="first-match" as="node()?">
         <call-template name="r:first-match-unordered">
            <with-param name="nodes" select="$relevant-nodes"/>
         </call-template>
      </variable>

      <sequence select="not(empty($first-match)), $first-match"/>
   </template>

   <template match="attribute" mode="r:li">
      <param name="n" as="node()"/>

      <choose>
         <when test="$n instance of attribute()">
            <variable name="name-matches" as="xs:boolean">
               <apply-templates select="*[1]" mode="#current">
                  <with-param name="n" select="$n"/>
               </apply-templates>
            </variable>
            <choose>
               <when test="$name-matches">
                  <variable name="matching-content" as="item()+">
                     <apply-templates select="*[2]" mode="r:ul">
                        <with-param name="nodes" as="text()">
                           <value-of select="$n"/>
                        </with-param>
                        <with-param name="context" select="$n" tunnel="yes"/>
                     </apply-templates>
                  </variable>
                  <sequence select="$matching-content[1]"/>
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

   <template match="text" mode="r:ol">
      <param name="nodes" as="node()*"/>

      <variable name="relevant-nodes" select="$nodes[not(self::attribute())]"/>

      <variable name="first-match" as="node()?">
         <call-template name="r:first-match-ordered">
            <with-param name="nodes" select="$relevant-nodes"/>
         </call-template>
      </variable>

      <sequence select="(not(empty($first-match)) or (not(parent::choice) or empty($relevant-nodes))), $first-match"/>
   </template>

   <template match="text" mode="r:ul">
      <param name="nodes" as="node()*"/>

      <variable name="relevant-nodes" select="$nodes[self::text()]"/>

      <sequence select="true(), $relevant-nodes"/>
   </template>

   <template match="text" mode="r:li">
      <param name="n" as="node()"/>
      <sequence select="$n instance of text()"/>
   </template>

   <!--
      ## Name classes
   -->

   <template match="name" mode="r:li">
      <param name="n" as="node()"/>

      <sequence select="not($n instance of text())
         and node-name($n) eq QName(@ns, text())"/>
   </template>

   <template match="anyName" mode="r:li">
      <param name="n" as="node()"/>

      <choose>
         <when test="except">
            <variable name="except-result" as="xs:boolean">
               <apply-templates select="except" mode="#current">
                  <with-param name="n" select="$n"/>
               </apply-templates>
            </variable>
            <sequence select="$except-result"/>
         </when>
         <otherwise>
            <sequence select="true()"/>
         </otherwise>
      </choose>
   </template>

   <template match="nsName" mode="r:li">
      <param name="n" as="node()"/>

      <variable name="ns-matches" select="not($n instance of text())
         and namespace-uri($n) eq @ns"/>

      <choose>
         <when test="except and $ns-matches">
            <variable name="except-result" as="xs:boolean">
               <apply-templates select="except" mode="#current">
                  <with-param name="n" select="$n"/>
               </apply-templates>
            </variable>
            <sequence select="$except-result"/>
         </when>
         <otherwise>
            <sequence select="$ns-matches"/>
         </otherwise>
      </choose>
   </template>

   <!--
      ## Strings
   -->

   <template match="value | data" mode="r:ol">
      <param name="nodes" as="node()*"/>

      <variable name="relevant-nodes" select="$nodes[not(self::attribute())]"/>

      <variable name="empty-text" as="text()">
         <text/>
      </variable>

      <variable name="modified-nodes" select="if (empty($nodes) and not(ancestor::list)) then $empty-text else $relevant-nodes"/>

      <variable name="first-match" as="node()?">
         <call-template name="r:first-match-ordered">
            <with-param name="nodes" select="$modified-nodes"/>
         </call-template>
      </variable>

      <sequence select="not(empty($first-match)), $first-match[not(. is $empty-text)]"/>
   </template>

   <template match="value | data" mode="r:ul">
      <param name="nodes" as="node()*"/>

      <variable name="relevant-nodes" select="$nodes[not(self::attribute())]"/>

      <variable name="empty-text" as="text()">
         <text/>
      </variable>

      <variable name="modified-nodes" select="if (empty($nodes) and not(ancestor::list)) then $empty-text else $relevant-nodes"/>

      <variable name="first-match" as="node()?">
         <call-template name="r:first-match-unordered">
            <with-param name="nodes" select="$modified-nodes"/>
         </call-template>
      </variable>

      <sequence select="not(empty($first-match)), $first-match[not(. is $empty-text)]"/>
   </template>

   <template match="value[@datatypeLibrary = '' and @type = 'token']" mode="r:li">
      <param name="n" as="node()"/>

      <sequence select="$n instance of text()
         and normalize-space($n) eq normalize-space()"/>
   </template>

   <template match="value[@datatypeLibrary = '' and @type = 'string']" mode="r:li">
      <param name="n" as="node()"/>

      <sequence select="$n instance of text()
         and string($n) eq string()"/>
   </template>

   <template match="data[@datatypeLibrary = '' and @type = ('token', 'string')]" mode="r:li">
      <param name="n" as="node()"/>

      <choose>
         <when test="$n instance of text()">
            <choose>
               <when test="except">
                  <variable name="except-result" as="xs:boolean">
                     <apply-templates select="except" mode="#current">
                        <with-param name="n" select="$n"/>
                     </apply-templates>
                  </variable>
                  <sequence select="$except-result"/>
               </when>
               <otherwise>
                  <sequence select="true()"/>
               </otherwise>
            </choose>
         </when>
         <otherwise>
            <sequence select="false()"/>
         </otherwise>
      </choose>
   </template>

   <template match="list" mode="r:ol">
      <param name="nodes" as="node()*"/>

      <variable name="relevant-nodes" select="$nodes[not(self::attribute())]"/>

      <choose>
         <when test="empty($relevant-nodes)">
            <apply-templates select="*" mode="#current">
               <with-param name="nodes" select="$relevant-nodes"/>
            </apply-templates>
         </when>
         <otherwise>
            <variable name="first-match" as="node()?">
               <call-template name="r:first-match-ordered">
                  <with-param name="nodes" select="$relevant-nodes"/>
               </call-template>
            </variable>
            <sequence select="not(empty($first-match)), $first-match"/>
         </otherwise>
      </choose>
   </template>

   <template match="list" mode="r:ul">
      <param name="nodes" as="node()*"/>

      <variable name="relevant-nodes" select="$nodes[not(self::attribute())]"/>

      <choose>
         <when test="empty($relevant-nodes)">
            <apply-templates select="*" mode="#current">
               <with-param name="nodes" select="$relevant-nodes"/>
            </apply-templates>
         </when>
         <otherwise>
            <variable name="first-match" as="node()?">
               <call-template name="r:first-match-unordered">
                  <with-param name="nodes" select="$relevant-nodes"/>
               </call-template>
            </variable>
            <sequence select="not(empty($first-match)), $first-match"/>
         </otherwise>
      </choose>
   </template>

   <template match="list" mode="r:li">
      <param name="n" as="node()"/>

      <choose>
         <when test="$n instance of text()">
            <variable name="content" as="text()*">
               <for-each select="tokenize(normalize-space($n), '\s')">
                  <value-of select="."/>
               </for-each>
            </variable>
            <variable name="matching-content" as="item()+">
               <apply-templates select="*" mode="r:ol">
                  <with-param name="nodes" select="$content"/>
               </apply-templates>
            </variable>
            <sequence select="$matching-content[1]
               and count($content) eq (count($matching-content) - 1)"/>
         </when>
         <otherwise>
            <sequence select="false()"/>
         </otherwise>
      </choose>
   </template>

   <!--
      ## Compositors
   -->

   <template match="choice" mode="r:ol r:ul">
      <param name="nodes" as="node()*"/>

      <variable name="left-matches" as="item()+">
         <apply-templates select="*[1]" mode="#current">
            <with-param name="nodes" select="$nodes"/>
         </apply-templates>
      </variable>

      <choose>
         <when test="$left-matches[1]">
            <sequence select="$left-matches"/>
         </when>
         <otherwise>
            <variable name="right-matches" as="item()+">
               <apply-templates select="*[2]" mode="#current">
                  <with-param name="nodes" select="$nodes"/>
               </apply-templates>
            </variable>
            <choose>
               <when test="$right-matches[1]">
                  <sequence select="$right-matches"/>
               </when>
               <otherwise>
                  <sequence select="boolean(*[1][self::empty])
                     and not(ancestor::attribute)"/>
               </otherwise>
            </choose>
         </otherwise>
      </choose>
   </template>

   <template match="choice" mode="r:li">
      <param name="n" as="node()"/>

      <variable name="left-matches" as="xs:boolean">
         <apply-templates select="*[1]" mode="#current">
            <with-param name="n" select="$n"/>
         </apply-templates>
      </variable>

      <choose>
         <when test="$left-matches">
            <sequence select="$left-matches"/>
         </when>
         <otherwise>
            <variable name="right-matches" as="xs:boolean">
               <apply-templates select="*[2]" mode="#current">
                  <with-param name="n" select="$n"/>
               </apply-templates>
            </variable>
            <sequence select="$right-matches 
               or (boolean(*[1][self::empty]) and not(ancestor::attribute))"/>
         </otherwise>
      </choose>
   </template>

   <template match="oneOrMore" mode="r:ol r:ul">
      <param name="nodes" as="node()*"/>

      <variable name="matching-nodes" as="item()+">
         <apply-templates select="*" mode="#current">
            <with-param name="nodes" select="$nodes"/>
         </apply-templates>
      </variable>

      <variable name="residual" select="$nodes[not(. intersect subsequence($matching-nodes, 2))]"/>

      <choose>
         <when test="$matching-nodes[1] and count($matching-nodes) gt 1 and $residual">
            <variable name="matching-residual" as="item()+">
               <apply-templates select="." mode="#current">
                  <with-param name="nodes" select="$residual"/>
               </apply-templates>
            </variable>
            <sequence select="if ($matching-residual[1]) then
               (true(), subsequence($matching-nodes, 2), subsequence($matching-residual, 2))
               else $matching-nodes"/>
         </when>
         <otherwise>
            <sequence select="$matching-nodes"/>
         </otherwise>
      </choose>
   </template>

   <template match="group" mode="r:ol">
      <param name="nodes" as="node()*"/>

      <variable name="left-matches" as="item()+">
         <apply-templates select="*[1]" mode="#current">
            <with-param name="nodes" select="$nodes"/>
         </apply-templates>
      </variable>

      <choose>
         <when test="$left-matches[1]">
            <variable name="left-residual" select="$nodes[not(. intersect subsequence($left-matches, 2))]"/>
            <variable name="right-matches" as="item()+">
               <apply-templates select="*[2]" mode="#current">
                  <with-param name="nodes" select="$left-residual"/>
               </apply-templates>
            </variable>
            <choose>
               <when test="$right-matches[1]">
                  <sequence select="true(), subsequence($left-matches, 2), subsequence($right-matches, 2)"/>
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

   <template match="group" mode="r:ul">
      <param name="nodes" as="node()*"/>

      <variable name="left-matches" as="item()+">
         <apply-templates select="*[1]" mode="#current">
            <with-param name="nodes" select="$nodes"/>
         </apply-templates>
      </variable>

      <choose>
         <when test="$left-matches[1]">
            <variable name="left-residual" select="
               if (count($left-matches) gt 1) then
                  $nodes[position() gt ($nodes/(if (. is $left-matches[last()]) then position() else ()))]
               else $nodes
            "/>
            <variable name="right-matches" as="item()+">
               <apply-templates select="*[2]" mode="#current">
                  <with-param name="nodes" select="$left-residual"/>
               </apply-templates>
            </variable>
            <choose>
               <when test="$right-matches[1]">
                  <sequence select="true(), subsequence($left-matches, 2), subsequence($right-matches, 2)"/>
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

   <template match="interleave" mode="r:ol r:ul">
      <param name="nodes" as="node()*"/>

      <variable name="left-matches" as="item()+">
         <apply-templates select="*[1]" mode="r:ul">
            <with-param name="nodes" select="$nodes"/>
         </apply-templates>
      </variable>

      <choose>
         <when test="$left-matches[1]">
            <variable name="left-residual" select="$nodes[not(. intersect subsequence($left-matches, 2))]"/>
            <variable name="right-matches" as="item()+">
               <apply-templates select="*[2]" mode="r:ul">
                  <with-param name="nodes" select="$left-residual"/>
               </apply-templates>
            </variable>
            <choose>
               <when test="$right-matches[1]">
                  <sequence select="true(), subsequence($left-matches, 2), subsequence($right-matches, 2)"/>
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

   <!--
      ## Other   
   -->

   <template match="except" mode="r:li">
      <param name="n" as="node()"/>

      <variable name="matches" as="xs:boolean">
         <apply-templates select="*" mode="#current">
            <with-param name="n" select="$n"/>
         </apply-templates>
      </variable>

      <sequence select="not($matches)"/>
   </template>

   <template match="notAllowed" mode="r:ol r:ul r:li">
      <sequence select="false()"/>
   </template>

   <template match="empty" mode="r:ol r:ul">
      <param name="nodes" as="node()*"/>

      <choose>
         <when test="count($nodes) eq 1">
            <variable name="result" as="xs:boolean">
               <apply-templates select="." mode="r:li">
                  <with-param name="n" select="$nodes"/>
               </apply-templates>
            </variable>
            <sequence select="$result, $nodes[$result]"/>
         </when>
         <otherwise>
            <sequence select="empty($nodes)"/>
         </otherwise>
      </choose>
   </template>

   <template match="empty" mode="r:li">
      <param name="n" as="node()"/>

      <sequence select="$n instance of text()
         and not(normalize-space($n))"/>
   </template>

   <!--
      ## Utilities   
   -->

   <template name="r:first-match-ordered">
      <param name="nodes" as="node()*"/>

      <variable name="n" select="$nodes[1]"/>

      <if test="$n">
         <variable name="result" as="xs:boolean">
            <apply-templates select="." mode="r:li">
               <with-param name="n" select="$n"/>
            </apply-templates>
         </variable>

         <if test="$result">
            <sequence select="$n"/>
         </if>
      </if>
   </template>

   <template name="r:first-match-unordered">
      <param name="nodes" as="node()*"/>

      <variable name="n" select="$nodes[1]"/>

      <if test="$n">
         <variable name="result" as="xs:boolean">
            <apply-templates select="." mode="r:li">
               <with-param name="n" select="$n"/>
            </apply-templates>
         </variable>
         <choose>
            <when test="$result">
               <sequence select="$n"/>
            </when>
            <otherwise>
               <call-template name="r:first-match-unordered">
                  <with-param name="nodes" select="$nodes[position() gt 1]"/>
               </call-template>
            </otherwise>
         </choose>
      </if>
   </template>

</stylesheet>