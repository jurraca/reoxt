
// Graph visualization hook for Phoenix LiveView
const GraphVisualization = {
  mounted() {
    console.log('GraphVisualization hook mounted');
    console.log('Container element:', this.el);
    
    // Wait for D3 to be available
    this.waitForD3(() => {
      this.initializeGraph();
    });

    // Listen for graph data updates from LiveView
    this.handleEvent("render_graph", (data) => {
      console.log('Received render_graph event:', data);
      this.renderGraph(data.graph_data);
    });

    this.handleEvent("clear_graph", () => {
      this.clearGraph();
    });
  },

  waitForD3(callback) {
    if (typeof d3 !== 'undefined') {
      callback();
    } else {
      // Load D3.js if not already available
      const script = document.createElement('script');
      script.src = 'https://d3js.org/d3.v7.min.js';
      script.onload = () => {
        console.log('D3.js loaded');
        callback();
      };
      script.onerror = () => {
        console.error('Failed to load D3.js');
      };
      document.head.appendChild(script);
    }
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
      .style("background", "linear-gradient(145deg, #0a0a0a 0%, #1a1a1a 100%)")
      .style("border-radius", "8px");

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
      console.error("Invalid graph data provided");
      return;
    }

    // Store current height for confirmations calculation
    this.currentHeight = graphData.current_height || 800000;

    console.log("Rendering graph with data:", graphData);

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
      .attr("stroke", "#39ff14")
      .attr("stroke-opacity", 0.7)
      .attr("stroke-width", d => Math.max(Math.sqrt(d.value) || 1, 2))
      .style("filter", "drop-shadow(0 0 4px #39ff14)");

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
      .attr("stroke", d => this.getNodeStrokeColor(d))
      .attr("stroke-width", 3)
      .style("filter", d => `drop-shadow(0 0 8px ${this.getNodeColor(d)})`);

    // Add labels
    nodeEnter.append("text")
      .attr("dx", 12)
      .attr("dy", ".35em")
      .style("font-size", "11px")
      .style("fill", "#e5e5e5")
      .style("font-weight", "500")
      .style("text-shadow", "0 0 4px rgba(57, 255, 20, 0.3)")
      .text(d => d.txid.substring(0, 8) + "...");

    // Add tooltips
    nodeEnter.append("title")
      .text(d => `TX: ${d.txid}\nValue: ${this.formatValue(d.total_output_value || 0)} BTC\nConfirmations: ${this.getConfirmations(d)}`);

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
    // Color based on confirmations and value with neon theme
    const confirmations = this.getConfirmations(node);
    const value = node.total_output_value || 0;

    if (confirmations === 0) {
      return "#ff1493"; // Neon pink for unconfirmed
    } else if (value > 100000000) { // > 1 BTC
      return "#39ff14"; // Neon green for high value
    } else if (confirmations < 6) {
      return "#00ffff"; // Neon cyan for low confirmations
    }
    return "#bf00ff"; // Neon purple for normal transactions
  },

  getNodeStrokeColor(node) {
    // Matching stroke colors with higher opacity
    const confirmations = this.getConfirmations(node);
    const value = node.total_output_value || 0;

    if (confirmations === 0) {
      return "#ff69b4"; // Lighter pink stroke
    } else if (value > 100000000) {
      return "#7fff00"; // Lighter green stroke
    } else if (confirmations < 6) {
      return "#87ceeb"; // Lighter cyan stroke
    }
    return "#da70d6"; // Lighter purple stroke
  },

  getConfirmations(node) {
    // Calculate confirmations based on block_height
    if (this.currentHeight && node.block_height) {
      return this.currentHeight - node.block_height;
    }
    return 0; // Default to 0 if calculation is not possible
  },

  formatValue(satoshis) {
    return (satoshis / 100000000).toFixed(8);
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
