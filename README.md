[rng.xsl](http://maxtoroq.github.io/rng.xsl/) — An XSLT 2.0 implementation of Relax NG
======================================================================================
rng.xsl is a Relax NG validator and simplifier written in XSLT 2.0. It supports XML syntax and XSD datatypes, leveraging XSLT's basic support for both XML and XSD primitive atomic types.

rng.xsl is **not** a streaming validator, it works on in-memory documents. Unlike most Relax NG implementations, it does not use the [derivative](http://www.thaiopensource.com/relaxng/derivative.html) algorithm. Instead, it walks the schema and pulls from the validating document to test the patterns.

## Features

rng.xsl is still under development. The planned features are:

- Customize error messages from your XSLT program
- Inject custom validation logic using XSLT templates
- Implement custom datatypes in XSLT

## Conformance

rng.xsl passes 343 out of 385 tests in [Jing's](http://jing-trang.googlecode.com/) [test suite](tests/spectest.xml). Most of the failing tests are related to [sections 7.3 and 7.4](http://www.relaxng.org/spec-20011203.html#attribute-restrictions) of the specification, and does not affect validation functionality. Just write correct schemas and you'll be fine.

There's only one failing test related to section 6, which involves the use of non-mutually exclusive choices. For example, given the following schema:

```xml
<element xmlns="http://relaxng.org/ns/structure/1.0" name="foo">
   <list>
      <choice>
         <value>x</value>
         <group>
            <value>x</value>
            <value>y</value>
         </group>
      </choice>
   </list>
</element>
```

rng.xsl correctly validates `<foo>x</foo>`, but fails for `<foo>x y</foo>`. However, such patterns are rarely used in real-world schemas. There are no plans to fix this issue.

## Feedback

Questions? Issues? use the [issue tracker](https://github.com/maxtoroq/rng.xsl/issues).