<%@ Page Language="C#" %>
<%@ Import Namespace="System.Web" %>
<%@ Import Namespace="System.Collections.Specialized" %>
<%@ Import Namespace="GuiCompare" %>
<!--

	  TODO:

	  Add Error messages generated by the compare process.


	  Cleanup:

	  * Change all the ComparisonNode public fields to use CamelCasing.
	  *  -->
<head>
  <script>
function StopEvent (e)
{
	if (e && e.stopPropogation) 
	   e.stopPropogation();
	else if (window.event && window.event.cancelBubble)
	   window.event.cancelBubble = true;
}

function ApiMessage (t)
{
	$.jGrowl (t);
}
  </script>
  <style type="text/css">
.icons {
  width: 12px;
  height: 1em;
  display: inline-block;
  background: no-repeat left bottom;
}

.creport {
	display: inline-block;
	cursor: pointer;
}

.report {
	display: inline-block;
}

.suffix {
	margin-left: 0.5em;
}
	  
.missing {
	background-image: url(sm.gif);
}

.extra {
	background-image: url(sx.gif);
}

.ok {
	background-image: url(sc.gif);
}

.warning {
	background-image: url(mn.png);
}

.niex {
	background-image: url(se.gif);
}

.todo {
	background-image: url(st.gif);
}

  </style>
</head>
<script runat="server" language="c#">

static string Get (int count, string kind, IList comments)
{
	if (count == 0)
		return "";
	
	string cstring;
	if (comments != null && comments.Count > 0){
	   	var sb = new StringBuilder ();
		foreach (var s in comments)
			sb.Append (s);
		cstring = sb.ToString ();
	} else
	  	cstring = "";

	return String.Format ("<div class='report' title='{0} {1} {2}'><div class='icons suffix {1}'></div>{0}</div>", count, kind, cstring);
}
	  
static string Get (int count, string kind)
{
	return Get (count, kind, null);
}

static string GetStatus (ComparisonNode n)
{
	string status = 
		Get (n.Missing, "missing") +
		Get (n.Extra, "extra") +
		Get (n.Warning, "warning") +
		Get (n.Todo, "todo", n.todos) +
		Get (n.Niex, "niex");

	if (status != "")
		return n.name + status;

	return n.name;
}
	  
public void Page_Load ()
{
	ComparisonNode n = global_asax.CompareContext.Comparison;

	//TreeNode tn = new TreeNode ("<img src='sm.gif' border=0 align=absmiddle>" + n.name);
	//TreeNode tn = new TreeNode (n.name);
	//TreeNode tn = new TreeNode ("<div class='ok'></div>" + n.name);

	TreeNode tn = new TreeNode (GetStatus (n), n.name);
	tn.SelectAction = TreeNodeSelectAction.None;
	tn.PopulateOnDemand = true;
	tree.Nodes.Add (tn);
}

static string Missing (string member)
{
	return "<img src='sm.gif' border=0 align=absmiddle>" + member;
}

static string Extra (string member)
{
	return "<img src='sx.gif' border=0 align=absmiddle>" + member;
}

static string Ok (string member)
{
	return "<img src='sc.gif' border=0 align=absmiddle>" + member;
}

static string Error (string member)
{
	return "<img src='se.gif' border=0 align=absmiddle>" + member;
}

string LeafMemberStatus (ComparisonNode cn)
{
	if (cn.Niex != 0)
		return Error ("");
	else
		return MemberStatus (cn);
}

static string MemberStatus (ComparisonNode cn)
{
	switch (cn.status){
	case ComparisonStatus.None:
		return Ok ("");
		
	case ComparisonStatus.Missing:
		return Missing ("");
		
	case ComparisonStatus.Extra:
		return Extra ("");
		
	case ComparisonStatus.Error:
		return Error ("");

	default:
		return "Unknown status: " + cn.status;
	}
}

ComparisonNode ComparisonNodeFromTreeNode (TreeNode tn)
{
	if (tn.Parent == null){
		return global_asax.CompareContext.Comparison;
		return null;
	}
	
	var match = ComparisonNodeFromTreeNode (tn.Parent);
	if (match == null)
		return null;
	foreach (var n in match.children){
		if (n.name == tn.Value)
			return n;
	}
	return null;
}

// uses for class, struct, enum, interface
static string GetFQN (ComparisonNode node)
{
	if (node.parent == null)
		return "";

	string n = GetFQN (node.parent);
	return n == "" ? node.name : n + "." + node.name;
}

// used for methods
static string GetMethodFQN (ComparisonNode node)
{
	if (node.parent == null)
		return "";

	int p = node.name.IndexOf ('(');
	int q = node.name.IndexOf (' ');
	
	string name = p == -1 || q == -1 ? node.name : node.name.Substring (q+1, p-q-1);
	
	string n = GetFQN (node.parent);
	return n == "" ? name : n + "." + name;
}

static string MakeURL (string type)
{
	return "http://msdn.microsoft.com/en-us/library/" + type.ToLower () + ".aspx";
}

static TreeNode MakeContainer (string kind, ComparisonNode node)
{
	TreeNode tn = new TreeNode (String.Format ("{0} {1} {2}", MemberStatus (node), kind, GetStatus (node)), node.name);
	
	tn.SelectAction = TreeNodeSelectAction.None;
	return tn;
}

void TreeNodePopulate (object sender, TreeNodeEventArgs e)
{
	Console.WriteLine ("Populating {0}", e.Node.Text);
	
	ComparisonNode cn = ComparisonNodeFromTreeNode (e.Node);
	if (cn == null){
		Console.WriteLine ("ERROR: Did not find the node");
		return;
	}

	foreach (var child in cn.children){
		TreeNode tn;

		switch (child.type){
		case CompType.Namespace:
			tn = new TreeNode (GetStatus (child), child.name);
			tn.SelectAction = TreeNodeSelectAction.None;
			break;

		case CompType.Class:
		        tn = MakeContainer ("class", child);
			break;

		case CompType.Struct:
		        tn = MakeContainer ("struct", child);
			break;
			
		case CompType.Interface:
		        tn = MakeContainer ("interface", child);
			break;
			
		case CompType.Enum:
		        tn = MakeContainer ("enum", child);
			break;

		case CompType.Method:
			tn = new TreeNode (LeafMemberStatus (child) + child.name, child.name);
			tn.NavigateUrl = MakeURL (GetMethodFQN (child));
			tn.Target = "_blank";
			break;
			
		case CompType.Property:
		case CompType.Field:
		case CompType.Delegate:
		case CompType.Event:
			tn = new TreeNode (MemberStatus (child) + " " + child.type.ToString() + " " + child.name, child.name);
			tn.NavigateUrl = MakeURL (GetFQN (child));
			tn.Target = "_blank";
			break;

		case CompType.Assembly:
		case CompType.Attribute:
			tn = new TreeNode (MemberStatus (child) + " " + child.type.ToString() + " " + child.name, child.name);
			break;

		default:
			tn = new TreeNode ("Unknown type: " + child.type.ToString());
			break;
		}

		if (child.children.Count != 0)
			tn.PopulateOnDemand = true;
		
		e.Node.ChildNodes.Add (tn);
	}
}
</script>

<body>
    <%=DateTime.Now %>

    <form id="form" runat="server">
    <div>
        <asp:TreeView ID="tree" Runat="server" OnTreeNodePopulate="TreeNodePopulate"
        EnableClientScript="true"
        PopulateNodesFromClient="true"
        ExpandDepth="0">
        </asp:TreeView>
    </div>
    </form>
</body>
</html>
