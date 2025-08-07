
// Graph visualization hook for Phoenix LiveView
const GraphVisualization = {
  mounted() {
    this.initializeGraph();
    
    // Listen for graph data updates from LiveView
    this.handleEvent("render_graph", (data) => {
      this.renderGraph(data.graph_data);
    });
    
    this.handleEvent("clear_graph", () => {
      this.clearGraph();
    });
  },

  initializeGraph() {
    // Set up the SVG container
    const container = this.el;
    const width = container.clientWidth;
    const height = container.clientHeight;

    // Clear any existing content
    container.innerHTML = '';

    // Create SVG element
    this.svg = d3.select(container)
      .append("svg")
      .attr("width", width)
      .attr("height", height)
      .style("background-color", "#f8f9fa");

    // Create groups for different elements
    this.linkGroup = this.svg.append("g").attr("class", "links");
    this.nodeGroup = this.svg.append("g").attr("class", "nodes");

    // Initialize zoom behavior
    const zoom = d3.zoom()
      .scaleExtent([0.1, 4])
      .on("zoom", (event) => {
        this.linkGroup.attr("transform", event.transform);
        this.nodeGroup.attr("transform", event.transform);
      });

    this.svg.call(zoom);

    // Set up force simulation
    this.simulation = d3.forceSimulation()
      .force("link", d3.forceLink().id(d => d.txid).distance(100))
      .force("charge", d3.forceManyBody().strength(-300))
      .force("center", d3.forceCenter(width / 2, height / 2))
      .force("collision", d3.forceCollide().radius(30));
  },

  renderGraph(graphData) {
    if (!graphData || !graphData.nodes || !graphData.edges) {
      return;
    }

    // Process nodes and links
    const nodes = graphData.nodes.map(node => ({
      ...node,
      id: node.txid,
      x: Math.random() * this.svg.attr("width"),
      y: Math.random() * this.svg.attr("height")
    }));

    const links = graphData.edges.map(edge => ({
      source: edge.from,
      target: edge.to,
      value: edge.value || 1
    }));

    // Update links
    const link = this.linkGroup
      .selectAll("line")
      .data(links, d => `${d.source}-${d.target}`);

    link.exit().remove();

    const linkEnter = link.enter()
      .append("line")
      .attr("stroke", "#999")
      .attr("stroke-opacity", 0.6)
      .attr("stroke-width", d => Math.sqrt(d.value) || 1);

    const linkUpdate = linkEnter.merge(link);

    // Update nodes
    const node = this.nodeGroup
      .selectAll("g")
      .data(nodes, d => d.id);

    node.exit().remove();

    const nodeEnter = node.enter()
      .append("g")
      .call(this.drag(this.simulation));

    // Add circles for nodes
    nodeEnter.append("circle")
      .attr("r", d => this.getNodeRadius(d))
      .attr("fill", d => this.getNodeColor(d))
      .attr("stroke", "#fff")
      .attr("stroke-width", 2);

    // Add labels
    nodeEnter.append("text")
      .attr("dx", 12)
      .attr("dy", ".35em")
      .style("font-size", "10px")
      .style("fill", "#333")
      .text(d => d.txid.substring(0, 8) + "...");

    // Add tooltips
    nodeEnter.append("title")
      .text(d => `TX: ${d.txid}\nValue: ${d.total_output_value || 0}\nConfirmations: ${d.confirmations || 0}`);

    const nodeUpdate = nodeEnter.merge(node);

    // Update simulation
    this.simulation
      .nodes(nodes)
      .on("tick", () => {
        linkUpdate
          .attr("x1", d => d.source.x)
          .attr("y1", d => d.source.y)
          .attr("x2", d => d.target.x)
          .attr("y2", d => d.target.y);

        nodeUpdate
          .attr("transform", d => `translate(${d.x},${d.y})`);
      });

    this.simulation.force("link").links(links);
    this.simulation.alpha(1).restart();
  },

  getNodeRadius(node) {
    // Scale radius based on transaction value
    const baseRadius = 8;
    const value = node.total_output_value || 0;
    
    if (value > 100000000) { // > 1 BTC
      return baseRadius * 2;
    } else if (value > 10000000) { // > 0.1 BTC
      return baseRadius * 1.5;
    }
    return baseRadius;
  },

  getNodeColor(node) {
    // Color based on confirmations and value
    const confirmations = node.confirmations || 0;
    const value = node.total_output_value || 0;

    if (confirmations === 0) {
      return "#ef4444"; // Red for unconfirmed
    } else if (value > 100000000) { // > 1 BTC
      return "#22c55e"; // Green for high value
    } else if (confirmations < 6) {
      return "#f59e0b"; // Orange for low confirmations
    }
    return "#3b82f6"; // Blue for normal transactions
  },

  clearGraph() {
    if (this.simulation) {
      this.simulation.stop();
    }
    
    this.linkGroup.selectAll("*").remove();
    this.nodeGroup.selectAll("*").remove();
  },

  drag(simulation) {
    function dragstarted(event, d) {
      if (!event.active) simulation.alphaTarget(0.3).restart();
      d.fx = d.x;
      d.fy = d.y;
    }
    
    function dragged(event, d) {
      d.fx = event.x;
      d.fy = event.y;
    }
    
    function dragended(event, d) {
      if (!event.active) simulation.alphaTarget(0);
      d.fx = null;
      d.fy = null;
    }
    
    return d3.drag()
      .on("start", dragstarted)
      .on("drag", dragged)
      .on("end", dragended);
  },

  destroyed() {
    if (this.simulation) {
      this.simulation.stop();
    }
  }
};

export default GraphVisualization;
