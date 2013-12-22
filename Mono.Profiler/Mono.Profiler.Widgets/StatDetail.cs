// Copyright (c) 2009  Novell, Inc.  <http://www.novell.com>
//
// Permission is hereby granted, free of charge, to any person obtaining
// a copy of this software and associated documentation files (the
// "Software"), to deal in the Software without restriction, including
// without limitation the rights to use, copy, modify, merge, publish,
// distribute, sublicense, and/or sell copies of the Software, and to
// permit persons to whom the Software is furnished to do so, subject to
// the following conditions:
// 
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
// LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
// OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
// WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


using System;
using System.Collections.Generic;
using Gdk;
using Gtk;

namespace Mono.Profiler.Widgets {

	[System.ComponentModel.ToolboxItem (true)]
	internal class StatDetail : Notebook {

		class PageView : ScrolledWindow {
	
			TreeView view;

			public PageView () : base ()
			{
				view = new TreeView ();
				view.AppendColumn ("Count", new CellRendererText (), "text", 1);
				view.AppendColumn ("Percent", new CellRendererText (), "text", 2);
				TreeViewColumn col = new TreeViewColumn ("Method", new CellRendererText (), "text", 0);
				view.AppendColumn (col);
				view.ExpanderColumn = col;
				view.Show ();
				Add (view);
			}

			public Store Store {
				set { view.Model = value == null ? null : new TreeModelAdapter (value); }
			}
		}

		class Store : ProfileStore {

			class CallInfoNode : Node {
		
				static List<Node> children = new List<Node> ();

				public static Comparison<Node> CompareByCalls = delegate (Node a, Node b) {
					return b.Value.CompareTo (a.Value);
				};

				StatisticalHitItemCallInformation info;
			
				public CallInfoNode (ProfileStore store, Node parent, StatisticalHitItemCallInformation info) : base (store, parent)
				{
					this.info = info;
				}
			
				public override List<Node> Children {
					get { return children; }
				}
			
				public override string Name {
					get { return info.Item.Name; }
				}
				
				public override ulong Value {
					get { return info.Calls; }
				}
			}
			
			ulong total_hits;
		
			public Store (ProfilerEventHandler data, DisplayOptions options, StatisticalHitItemCallInformation[] infos, ulong total_hits) : base (data, options)
			{
				this.total_hits = total_hits;
				nodes = new List<Node> ();
				foreach (StatisticalHitItemCallInformation info in infos)
					nodes.Add (new CallInfoNode (this, null, info));
				nodes.Sort (CallInfoNode.CompareByCalls);
			}

			public override void GetValue (Gtk.TreeIter iter, int column, ref GLib.Value val)
			{
				Node node = (Node) iter;
				if (column == 0)
					val = new GLib.Value (node.Name);
				else if (column == 1)
					val = new GLib.Value (node.Value.ToString ());
				else if (column == 2)
				{
					double percent = (double) node.Value / (double) total_hits * 100.0;
					val = new GLib.Value (String.Format ("{0,5:F2}%", percent));
				}
			}		
		}

		DisplayOptions options;
		PageView callers;
		PageView calls;
		ProfilerEventHandler data;
		
		ulong total_hits;
		
		public StatDetail (ProfilerEventHandler data, DisplayOptions options)
		{
			this.data = data;
			this.options = options;
			foreach (IStatisticalHitItem item in data.StatisticalHitItems)
				total_hits += item.StatisticalHits;
			options.Changed += delegate { Refresh (); };
			Label callers_lbl = new Label (Mono.Unix.Catalog.GetString ("Callers"));
			callers_lbl.Show ();
			Label calls_lbl = new Label (Mono.Unix.Catalog.GetString ("Calls"));
			calls_lbl.Show ();
			callers = new PageView ();
			callers.Show ();
			calls = new PageView ();
			calls.Show ();
			AppendPage (calls, calls_lbl);
			AppendPage (callers, callers_lbl);
		}

		void Refresh ()
		{
			if (item.HasCallCounts) {
				calls.Store = new Store (data, options, item.CallCounts.Callees, total_hits);
				callers.Store = new Store (data, options, item.CallCounts.Callers, total_hits);
			} else {
				calls.Store = null;
				callers.Store = null;
			}
		}

		IStatisticalHitItem item;

		public IStatisticalHitItem CurrentItem {
			get { return item; }
			set {
				if (item == value)
					return;

				item = value;
				Refresh ();
			}
		}
	}
}
