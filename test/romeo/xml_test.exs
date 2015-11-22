defmodule Romeo.XMLTest do
  use ExUnit.Case, async: true

  use Romeo.XML

  test "encode!" do
    xml = xmlel(name: "message", children: [
      xmlel(name: "body", children: [
        xmlcdata(content: "testing")
      ])
    ])
    assert Romeo.XML.encode!(xml) ==
      ~s(<message><body>testing</body></message>)
  end

  test "attr" do
    xml = xmlel(name: "message", attrs: [{"type", "chat"}])
    assert XML.attr(xml, "type") == "chat"
    assert XML.attr(xml, "non-existent") == nil
    assert XML.attr(xml, "non-existent", "default") == "default"
  end

  test "subelement" do
    xml = xmlel(name: "message", children: [
      xmlel(name: "body", children: [
        xmlcdata(content: "testing")
      ])
    ])
    assert XML.subelement(xml, "body") ==
      {:xmlel, "body", [], [xmlcdata(content: "testing")]}
  end

  test "cdata" do
    body = xmlel(name: "body", children: [
      xmlcdata(content: "testing")
    ])
    assert XML.cdata(body) == "testing"
  end

  test "empty cdata" do
    body = xmlel(name: "body", children: [
      xmlcdata(content: "testing")
    ])
    assert XML.cdata(body) == "testing"
  end
end
