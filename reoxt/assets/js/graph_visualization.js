
// Import D3 from CDN since the npm import isn't working
// We'll load it dynamically to ensure it's available
const GraphVisualization = {
  mounted() {
    console.log('GraphVisualization hook mounted');
    
    // Load D3 dynamically if not already loaded
    this.loadD3().then(() => {
      this.initializeGraph();

      // Listen for graph data updates from LiveView
      this.handleEvent("render_graph", (data) => {
        console.log('Received render_graph event:', data);
        this.renderGraph(data.graph_data);
      });

      this.handleEvent("clear_graph", () => {
        this.clearGraph();
      });
    });
  },

  loadD3() {
    return new Promise((resolve) => {
      if (typeof d3 !== 'undefined') {
        resolve();
        return;
      }
      
      const script = document.createElement('script');
      script.src = 'https://d3js.org/d3.v7.min.js';
      script.onload = () => {
        console.log('D3 loaded successfully');
        resolve();
      };
      document.head.appendChild(script);
    });
  },

  initializeGraph() {
    const container = this.el;
    console.log("Container element:", container);
    
    const width = container.clientWidth || 800;
    const height = container.clientHeight || 600;

    // Clear any existing content
    container.innerHTML = '';

    // Create SVG with D3
    this.svg = d3.select(container)
      .append("svg")
      .attr("width", width)
      .attr("height", height)
      .attr("viewBox", `0 0 ${width} ${height}`)
      .style("background", "#0a0a0a")
      .style("border-radius", "8px")
      .style("max-width", "100%")
      .style("height", "auto");

    // Store dimensions for later use
    this.width = width;
    this.height = height;

    console.log('Graph initialized with dimensions:', { width, height });
    console.log('SVG element created by D3');
  },

  renderGraph(graphData) {
    if (!graphData || !graphData.nodes || !graphData.edges) {
      console.error("Invalid graph data provided");
      return;
    }

    console.log("Rendering graph:", graphData.nodes.length, "nodes,", graphData.edges.length, "edges");

    // Prepare data like the example - simple structure
    const nodes = graphData.nodes.map(d => ({ 
      id: d.txid,
      group: 1  // Simple grouping for color
    }));

    const links = graphData.edges.map(d => ({ 
      source: d.from, 
      target: d.to,
      value: 1  // Simple value for stroke width
    }));

    console.log("Processed nodes:", nodes.length);
    console.log("Processed links:", links.length);

    // Color scale like the example
    const color = d3.scaleOrdinal(d3.schemeCategory10);

    // Create simulation exactly like the example
    this.simulation = d3.forceSimulation(nodes)
      .force("link", d3.forceLink(links).id(d => d.id))
      .force("charge", d3.forceManyBody().strength(-300))
      .force("center", d3.forceCenter(this.width / 2, this.height / 2))
      .on("tick", () => this.ticked());

    // Clear previous graph elements
    this.svg.selectAll("*").remove();

    // Add links exactly like the example
    this.linkElements = this.svg.append("g")
      .attr("stroke", "#39ff14")
      .attr("stroke-opacity", 0.6)
      .selectAll()
      .data(links)
      .join("line")
      .attr("stroke-width", d => Math.sqrt(d.value) * 2);

    // Add nodes exactly like the example
    this.nodeElements = this.svg.append("g")
      .attr("stroke", "#da70d6")
      .attr("stroke-width", 2)
      .selectAll()
      .data(nodes)
      .join("circle")
      .attr("r", 8)
      .attr("fill", "#bf00ff");

    // Add tooltips like the example
    this.nodeElements.append("title")
      .text(d => `TX: ${d.id.substring(0, 16)}...`);

    // Add drag behavior exactly like the example
    this.nodeElements.call(d3.drag()
      .on("start", (event) => this.dragstarted(event))
      .on("drag", (event) => this.dragged(event))
      .on("end", (event) => this.dragended(event)));

    console.log("Starting simulation with", nodes.length, "nodes and", links.length, "links");

    // Start simulation
    this.simulation.alpha(0.8).restart();
  },

  // Tick function exactly like the example
  ticked() {
    if (this.linkElements) {
      this.linkElements
        .attr("x1", d => d.source.x)
        .attr("y1", d => d.source.y)
        .attr("x2", d => d.target.x)
        .attr("y2", d => d.target.y);
    }

    if (this.nodeElements) {
      this.nodeElements
        .attr("cx", d => d.x)
        .attr("cy", d => d.y);
    }
  },

  // Drag functions exactly like the example
  dragstarted(event) {
    if (!event.active) this.simulation.alphaTarget(0.3).restart();
    event.subject.fx = event.subject.x;
    event.subject.fy = event.subject.y;
  },

  dragged(event) {
    event.subject.fx = event.x;
    event.subject.fy = event.y;
  },

  dragended(event) {
    if (!event.active) this.simulation.alphaTarget(0);
    event.subject.fx = null;
    event.subject.fy = null;
  },

  clearGraph() {
    if (this.simulation) {
      this.simulation.stop();
    }
    if (this.svg) {
      this.svg.selectAll("*").remove();
    }
  },

  destroyed() {
    if (this.simulation) {
      this.simulation.stop();
    }
  }
};

export default GraphVisualization;
