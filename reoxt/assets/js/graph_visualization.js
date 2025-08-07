import * as d3 from "d3";

const GraphVisualization = {
  mounted() {
    console.log('GraphVisualization hook mounted');
    this.initializeGraph();

    // Listen for graph data updates from LiveView
    this.handleEvent("render_graph", (data) => {
      console.log('Received render_graph event:', data);
      this.renderGraph(data.graph_data);
    });

    this.handleEvent("clear_graph", () => {
      this.clearGraph();
    });
  },

  initializeGraph() {
    const container = this.el;
    console.log("this", container)
    const width = container.clientWidth || 800;
    const height = container.clientHeight || 600;

    // Clear any existing content
    container.innerHTML = '';

    // Create SVG
    this.svg = d3.select(container)
      .append("svg")
      .attr("width", width)
      .attr("height", height)
      .style("background", "#0a0a0a")
      .style("border-radius", "8px");

    // Create groups for links and nodes
    this.linkGroup = this.svg.append("g").attr("class", "links");
    this.nodeGroup = this.svg.append("g").attr("class", "nodes");

    // Create force simulation
    this.simulation = d3.forceSimulation()
      .force("link", d3.forceLink().id(d => d.id).distance(100))
      .force("charge", d3.forceManyBody().strength(-300))
      .force("center", d3.forceCenter(width / 2, height / 2));

    // Add zoom behavior
    const zoom = d3.zoom()
      .scaleExtent([0.1, 4])
      .on("zoom", (event) => {
        this.linkGroup.attr("transform", event.transform);
        this.nodeGroup.attr("transform", event.transform);
      });

    this.svg.call(zoom);

    console.log('Graph initialized with dimensions:', { width, height });
  },

  renderGraph(graphData) {
    if (!graphData || !graphData.nodes || !graphData.edges) {
      console.error("Invalid graph data provided");
      return;
    }

    console.log("Rendering graph:", graphData.nodes.length, "nodes,", graphData.edges.length, "edges");

    // Prepare data with proper structure
    const nodes = graphData.nodes.map(d => ({ 
      ...d, 
      id: d.txid,
      x: Math.random() * 400 + 200,
      y: Math.random() * 300 + 150
    }));

    const links = graphData.edges.map(d => ({ 
      source: d.from, 
      target: d.to,
      type: d.type || 'default'
    }));

    console.log("Processed nodes:", nodes.length);
    console.log("Processed links:", links.length);

    // Store data references for tick function
    this.currentNodes = nodes;
    this.currentLinks = links;

    // Update simulation data
    this.simulation.nodes(nodes);
    this.simulation.force("link").links(links);

    // Use D3's general update pattern for links
    const linkSelection = this.linkGroup
      .selectAll("line")
      .data(links, d => `${d.source.id || d.source}-${d.target.id || d.target}`);

    // Remove old links
    linkSelection.exit().remove();

    // Add new links
    const linkEnter = linkSelection.enter()
      .append("line")
      .attr("stroke", "#39ff14")
      .attr("stroke-opacity", 0.6)
      .attr("stroke-width", 2);

    // Merge enter + update selections
    this.linkElements = linkEnter.merge(linkSelection);

    // Use D3's general update pattern for nodes
    const nodeSelection = this.nodeGroup
      .selectAll("g.node")
      .data(nodes, d => d.id);

    // Remove old nodes
    nodeSelection.exit().remove();

    // Add new nodes
    const nodeEnter = nodeSelection.enter()
      .append("g")
      .attr("class", "node")
      .call(this.drag());

    // Add circle to new nodes
    nodeEnter.append("circle")
      .attr("r", 8)
      .attr("fill", "#bf00ff")
      .attr("stroke", "#da70d6")
      .attr("stroke-width", 2);

    // Add tooltips to new nodes
    nodeEnter.append("title")
      .text(d => `TX: ${d.txid.substring(0, 16)}...`);

    // Merge enter + update selections
    this.nodeElements = nodeEnter.merge(nodeSelection);

    // Update tick function with stored references
    this.simulation.on("tick", () => {
      if (this.linkElements) {
        this.linkElements
          .attr("x1", d => d.source.x || 0)
          .attr("y1", d => d.source.y || 0)
          .attr("x2", d => d.target.x || 0)
          .attr("y2", d => d.target.y || 0);
      }

      if (this.nodeElements) {
        this.nodeElements
          .attr("transform", d => `translate(${d.x || 0},${d.y || 0})`);
      }
    });

    console.log("Starting simulation with", nodes.length, "nodes and", links.length, "links");

    // Restart simulation with higher alpha for better initial layout
    this.simulation.alpha(0.8).restart();
  },

  drag() {
    function dragstarted(event, d) {
      if (!event.active) this.simulation.alphaTarget(0.3).restart();
      d.fx = d.x;
      d.fy = d.y;
    }

    function dragged(event, d) {
      d.fx = event.x;
      d.fy = event.y;
    }

    function dragended(event, d) {
      if (!event.active) this.simulation.alphaTarget(0);
      d.fx = null;
      d.fy = null;
    }

    return d3.drag()
      .on("start", dragstarted.bind(this))
      .on("drag", dragged)
      .on("end", dragended.bind(this));
  },

  clearGraph() {
    if (this.simulation) {
      this.simulation.stop();
    }
    if (this.linkGroup) {
      this.linkGroup.selectAll("*").remove();
    }
    if (this.nodeGroup) {
      this.nodeGroup.selectAll("*").remove();
    }
  },

  destroyed() {
    if (this.simulation) {
      this.simulation.stop();
    }
  }
};

export default GraphVisualization;