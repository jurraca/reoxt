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

    // Prepare data
    const nodes = graphData.nodes.map(d => ({ ...d, id: d.txid }));
    const links = graphData.edges.map(d => ({ source: d.from, target: d.to }));

    // Update simulation
    this.simulation
      .nodes(nodes)
      .force("link").links(links);

    // Render links
    const link = this.linkGroup
      .selectAll("line")
      .data(links);

    link.enter()
      .append("line")
      .attr("stroke", "#39ff14")
      .attr("stroke-opacity", 0.6)
      .attr("stroke-width", 2);

    link.exit().remove();

    // Render nodes
    const node = this.nodeGroup
      .selectAll("circle")
      .data(nodes);

    const nodeEnter = node.enter()
      .append("circle")
      .attr("r", 8)
      .attr("fill", "#bf00ff")
      .attr("stroke", "#da70d6")
      .attr("stroke-width", 2)
      .call(this.drag());

    // Add tooltips
    nodeEnter.append("title")
      .text(d => `TX: ${d.txid.substring(0, 16)}...`);

    node.exit().remove();

    // Update simulation tick
    this.simulation.on("tick", () => {
      this.linkGroup.selectAll("line")
        .attr("x1", d => d.source.x)
        .attr("y1", d => d.source.y)
        .attr("x2", d => d.target.x)
        .attr("y2", d => d.target.y);

      this.nodeGroup.selectAll("circle")
        .attr("cx", d => d.x)
        .attr("cy", d => d.y);
    });

    // Restart simulation
    this.simulation.alpha(1).restart();
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