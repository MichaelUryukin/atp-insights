from dash import Dash, dcc, html, dash_table, Input, Output, State, callback
from dash.exceptions import PreventUpdate
import logging

logger = logging.getLogger(__name__)

# Initialize Dash app (like the working example)


# Set layout directly - simple and immediate (like the working example)
# CRITICAL: This must be set at module level before any other code runs
# Match the working example pattern exactly
app.layout = html.Div([
    html.H1("🎾 ATP Insights Agent", style={"textAlign": "center", "marginBottom": "20px", "color": "#333"}),
    dcc.Store(id='messages', data=[]),
    html.Div([
        html.Label("Ask your question", htmlFor="search_input", style={"marginRight": "10px", "fontWeight": "bold", "minWidth": "150px"}),
        html.Div([
            dcc.Input(id="search_input", placeholder="What can I do for you?", type="text", style={
                "width": "100%",
                "padding": "10px",
                "fontSize": "16px",
                "border": "1px solid #ddd",
                "borderRadius": "4px"
            }),
            dcc.Loading(id="ls-loading-1", children=[html.Div(id="ls-loading-output-1")], type="default")
        ], style={"flex": "1"})
    ], style={"marginBottom": "20px", "display": "flex", "alignItems": "center", "padding": "0 20px"}),
    html.Div([
        html.Div(style={"width": "10%", "display": "inline-block"}),
        html.Div([
            dcc.Textarea(
                id="text_output",
                style={
                    "height": "400px",
                    "width": "100%",
                    "padding": "10px",
                    "fontSize": "14px",
                    "border": "1px solid #ddd",
                    "borderRadius": "4px",
                    "fontFamily": "monospace"
                },
                readOnly=True
            )
        ], style={"width": "90%", "display": "inline-block"})
    ], style={"padding": "20px"})
], style={"maxWidth": "1200px", "margin": "0 auto", "padding": "20px"})

# ============================================================================
# AGENT CODE - DEFINED AFTER APP AND LAYOUT ARE SET
# ============================================================================

# Import agent-related modules AFTER layout is set (to avoid blocking layout setup)
from langchain_core.messages import ToolMessage, SystemMessage
import dataiku
from dataiku.llm.python import BaseLLM

SNOWFLAKE_CORTEX_CONNECTION_NAME = "snowflake_cortex"

# Initialize agent tools variables - will be set lazily when needed
cortex_search_tool = None
cortex_analyst_tool = None
tools = []

# Tool descriptions - defined here for use later
search_description = """Use Cortex Search when asked about emotions, mood, flow of the match, or narrative descriptions of matches. 
This tool searches through match summaries and descriptions to find relevant information about the emotional and narrative aspects of tennis matches.
Use this for questions about match intensity, player emotions, match flow, dramatic moments, or storytelling aspects."""

analyst_description = """Use Cortex Analyst when asked about statistical things, numbers, aggregations, or data analysis.
This tool queries the semantic model to answer questions about match statistics, player performance metrics, tournament data, and analytical queries.
Use this for questions about counts, averages, comparisons, rankings, or any numerical analysis."""

def add_tool_to_list(tool_obj, tool_type="", description=""):
    """Helper function to add a tool to the tools list."""
    if tool_obj:
        print(f"DEBUG: Adding {tool_type} tool to list...")
        from langchain_core.tools import tool
        
        # Create tool with docstring - need to create unique function for each tool
        if tool_type == "Cortex Search":
            @tool
            def cortex_search_tool(query: str) -> str:
                """Use Cortex Search when asked about emotions, mood, flow of the match, or narrative descriptions of matches. This tool searches through match summaries and descriptions to find relevant information about the emotional and narrative aspects of tennis matches. Use this for questions about match intensity, player emotions, match flow, dramatic moments, or storytelling aspects."""
                return tool_obj.run({"query": query})
            manual_tool = cortex_search_tool
        elif tool_type == "Cortex Analyst":
            @tool
            def cortex_analyst_tool(query: str) -> str:
                """Use Cortex Analyst when asked about statistical things, numbers, aggregations, or data analysis. This tool queries the semantic model to answer questions about match statistics, player performance metrics, tournament data, and analytical queries. Use this for questions about counts, averages, comparisons, rankings, or any numerical analysis."""
                return tool_obj.run({"query": query})
            manual_tool = cortex_analyst_tool
        else:
            @tool
            def manual_tool_wrapper(query: str) -> str:
                """Tool for querying data."""
                return tool_obj.run({"query": query})
            manual_tool = manual_tool_wrapper
        
        tools.append(manual_tool)
        print(f"DEBUG: Created manual tool wrapper for {tool_type}")


class MyLLM(BaseLLM):
    def __init__(self):
        pass

    def process(self, query, settings, trace):
        print(f"DEBUG: Starting process() with settings: {settings}")
        print(f"DEBUG: Query messages: {len(query.get('messages', []))} messages")
        
        project = dataiku.api_client().get_default_project()
        
        # Get model name from settings
        model_name = settings.get("model", "claude-3-5-sonnet")
        print(f"DEBUG: Model name from settings: {model_name}")
        
        # List available LLMs and find matching one
        print("DEBUG: Listing all LLMs in project...")
        all_llms = project.list_llms()
        print(f"DEBUG: Found {len(all_llms)} LLMs in project")
        for i, llm_info in enumerate(all_llms):
            print(f"DEBUG: LLM {i}: {llm_info}")
        
        llm_obj = None
        
        # Try to find LLM by matching model name in the list
        print("DEBUG: Searching for matching LLM in list...")
        for llm_info in all_llms:
            if isinstance(llm_info, dict):
                llm_id = llm_info.get("id")
                llm_model = llm_info.get("model", "")
                # Match by model name or if it's a Snowflake Cortex LLM
                if llm_id and (model_name.lower() in llm_model.lower() or 
                              (llm_info.get("type") == "SNOWFLAKE_CORTEX" and 
                               model_name.lower() in llm_model.lower())):
                    print(f"DEBUG: Found matching LLM: {llm_id}, model: {llm_model}")
                    try:
                        llm_obj = project.get_llm(llm_id)
                        print(f"DEBUG: Successfully retrieved LLM using ID: {llm_id}")
                        break
                    except Exception as e:
                        print(f"DEBUG: Failed to get LLM with ID {llm_id}: {e}")
                        continue
        
        if llm_obj is None:
            error_msg = f"Could not retrieve LLM for model '{model_name}'"
            print(f"DEBUG: ERROR - {error_msg}")
            raise Exception(error_msg)
        
        print(f"DEBUG: LLM object retrieved, type: {type(llm_obj)}")
        
        # Convert to LangChain chat model
        print("DEBUG: Converting LLM object to LangChain chat model...")
        try:
            llm = llm_obj.as_langchain_chat_model(completion_settings=settings)
            print("DEBUG: LangChain chat model created successfully")
        except Exception as e:
            print(f"DEBUG: ERROR converting to LangChain model: {e}")
            raise
        
        # Bind tools if available
        print(f"DEBUG: Binding tools to LLM. Tools count: {len(tools)}")
        if tools:
            print("DEBUG: Tools available, binding to LLM...")
            for i, tool in enumerate(tools):
                print(f"DEBUG: Tool {i}: {tool.name if hasattr(tool, 'name') else type(tool)}")
            llm_with_tools = llm.bind_tools(tools)
            print("DEBUG: Tools bound successfully")

        messages = [m for m in query["messages"] if m.get("content")]
        print(f"DEBUG: Processing {len(messages)} messages")
        
        # Add system message with instructions about tool usage and response format
        system_instruction = """When answering questions, always mention which tool you are using.
When asked about emotions, mood, flow of the match - use Cortex Search on match summaries.
When asked about statistical things - use Cortex Analyst to query the semantic model.
When asked a combination - use both tools.

In your responses:
- Tell a story with structure, don't use numbered bullets
- Show intermediate results from tools
- Avoid using the colon symbol (:) too much
- Explain what you found and how it answers the question"""
        
        # Prepend system message if not already present
        if not any(isinstance(m, SystemMessage) for m in messages):
            messages.insert(0, SystemMessage(content=system_instruction))
        
        iterations = 0
        
        while True:
            iterations += 1
            print(f"DEBUG: Iteration {iterations}")
            
            # Rebind tools in each iteration to ensure tool definitions are included
            print("DEBUG: Rebinding tools for this iteration...")
            current_llm_with_tools = llm.bind_tools(tools)
            with trace.subspan("Invoke LLM with tools") as llm_invoke_span:
                llm_response = current_llm_with_tools.invoke(messages)
                print(f"DEBUG: LLM response received. Has tool_calls: {hasattr(llm_response, 'tool_calls')}")

            if not hasattr(llm_response, 'tool_calls') or len(llm_response.tool_calls) == 0:
                print("DEBUG: No tool calls detected, returning text response")
                return {"text": llm_response.content}
            
            print(f"DEBUG: Tool calls detected: {len(llm_response.tool_calls)}")
            for i, tc in enumerate(llm_response.tool_calls):
                print(f"DEBUG: Tool call {i}: name='{tc.get('name')}', args={tc.get('args')}")
            
            print("DEBUG: Processing tool calls...")
            with llm_invoke_span.subspan("Call the tools") as tools_subspan:
                messages.append(llm_response)
                for tool_call in llm_response.tool_calls:
                    tool_name = tool_call["name"]
                    tool_args = tool_call["args"]
                    print(f"DEBUG: Executing tool call: name='{tool_name}', args={tool_args}")
                    
                    with tools_subspan.subspan("Call a tool") as tool_subspan:
                        tool_subspan.attributes["tool_name"] = tool_name
                        tool_subspan.attributes["tool_args"] = tool_args
                        
                        # Determine which tool to use based on tool name
                        tool_output = None
                        tool_used = None
                        
                        if cortex_search_tool:
                            search_tool_name = cortex_search_tool.name if hasattr(cortex_search_tool, 'name') else None
                            if tool_name == search_tool_name or "search" in tool_name.lower():
                                print(f"DEBUG: Using Cortex Search tool")
                                tool_used = "Cortex Search"
                                tool_output = cortex_search_tool.run(tool_args)
                                print(f"DEBUG: Cortex Search tool output received, length: {len(str(tool_output))}")
                        
                        if tool_output is None and cortex_analyst_tool:
                            analyst_tool_name = cortex_analyst_tool.name if hasattr(cortex_analyst_tool, 'name') else None
                            if tool_name == analyst_tool_name or "analyst" in tool_name.lower():
                                print(f"DEBUG: Using Cortex Analyst tool")
                                tool_used = "Cortex Analyst"
                                tool_output = cortex_analyst_tool.run(tool_args)
                                print(f"DEBUG: Cortex Analyst tool output received, length: {len(str(tool_output))}")
                        
                        # Add tool name to output so LLM knows which tool was used
                        if tool_used:
                            tool_output = f"[Using {tool_used} tool]\n\n{tool_output}"
                    
                    print(f"DEBUG: Tool message added to conversation")
                    messages.append(ToolMessage(tool_call_id=tool_call["id"], content=str(tool_output)))

# ============================================================================
# AGENT INITIALIZATION - HAPPENS AFTER APP AND LAYOUT ARE SET
# ============================================================================

# Initialize agent tools AFTER app and layout are set
def initialize_agent_tools():
    """Initialize agent tools - called after app is created."""
    global cortex_search_tool, cortex_analyst_tool, tools
    
    try:
        # Get the Cortex Search tool
        print("DEBUG: Getting project and listing agent tools...")
        project = dataiku.api_client().get_default_project()
        project_visual_tools = project.list_agent_tools()
        print(f"DEBUG: Found {len(project_visual_tools)} agent tools")
        for tool in project_visual_tools:
            print(f"DEBUG: Available tool - name: '{tool.get('name')}', id: '{tool.get('id')}'")

        def find_tool(name: str):
            """Find a tool by name."""
            print(f"DEBUG: Searching for tool with name: '{name}'")
            for tool in project_visual_tools:
                if tool["name"] == name:
                    print(f"DEBUG: Found tool '{name}' with id: '{tool['id']}'")
                    tool_obj = project.get_agent_tool(tool['id'])
                    print(f"DEBUG: Tool object type: {type(tool_obj)}")
                    return tool_obj
            print(f"DEBUG: Tool '{name}' not found")
            return None

        # Get the Snowflake Cortex Search tool
        print("DEBUG: Looking for 'Snowflake Cortex Search' tool...")
        cortex_search_tool = find_tool("Snowflake Cortex Search")
        # Get the Snowflake Cortex Analyst tool
        print("DEBUG: Looking for 'Snowflake Cortex Analyst' tool...")
        cortex_analyst_tool = find_tool("Snowflake Cortex Analyst")
        
        # Add tools to list
        add_tool_to_list(cortex_search_tool, "Cortex Search", search_description)
        add_tool_to_list(cortex_analyst_tool, "Cortex Analyst", analyst_description)

        print(f"DEBUG: Total tools available: {len(tools)}")
    except Exception as e:
        print(f"WARNING: Failed to initialize agent tools: {e}")
        import traceback
        traceback.print_exc()

# Initialize the LLM instance lazily - only when needed
llm_instance = None

def get_llm_instance():
    """Lazy initialization of LLM instance."""
    global llm_instance
    if llm_instance is None:
        try:
            print("DEBUG: Initializing LLM instance...")
            llm_instance = MyLLM()
            # Initialize tools after LLM is created
            initialize_agent_tools()
            print("DEBUG: LLM instance initialized successfully")
        except Exception as e:
            print(f"WARNING: Failed to initialize LLM instance: {e}")
            import traceback
            traceback.print_exc()
            llm_instance = None
    return llm_instance


@app.callback(
    [Output("ls-loading-output-1", "children"),
     Output("text_output", "value"),
     Output("messages", "data")],
    Input("search_input", "n_submit"),
    State("search_input", "value"),
    State("messages", "data"),
    prevent_initial_call=True
)
def get_answer(_, question, messages):
    """
    Ask a question to the agent and get back the response
    Args:
        _: number of enter pressed in the input text (not used)
        question: the question
        messages: the conversation history

    Returns:
        the response, and an updated version of the context
    """
    if not question or messages is None:
        raise PreventUpdate
    
    # Lazy initialize LLM if not already initialized
    llm = get_llm_instance()
    if llm is None:
        error_msg = "Agent not initialized. Please check server logs."
        messages.append({"role": "assistant", "content": error_msg})
        return ["", error_msg, messages]

    # Limit message history (keep last 20 messages)
    max_messages = 20
    while len(messages) > max_messages:
        messages.pop(0)  # Remove oldest messages
    
    # Add user message
    messages.append({"role": "user", "content": question})
    
    try:
        # Create query format for Dataiku LLM
        query = {
            "messages": messages
        }
        settings = {"model": "claude-3-5-sonnet"}
        
        # Create a simple trace object
        class SimpleTrace:
            def __init__(self):
                self.current_span = None
            
            def subspan(self, name):
                span = SimpleSpan(name)
                self.current_span = span
                return span
        
        class SimpleSpan:
            def __init__(self, name):
                self.name = name
                self.attributes = {}
                self.current_subspan = None
            
            def subspan(self, name):
                subspan = SimpleSpan(name)
                self.current_subspan = subspan
                return subspan
            
            def __enter__(self):
                return self
            
            def __exit__(self, *args):
                pass
        
        trace = SimpleTrace()
        
        # Process with agent
        result = llm.process(query, settings, trace)
        answer_text = result.get("text", "No response generated")
        
        # Add assistant message
        messages.append({"role": "assistant", "content": answer_text})
        
        return ["", answer_text, messages]
        
    except Exception as e:
        import traceback
        error_details = traceback.format_exc()
        print(f"ERROR in get_answer: {error_details}")
        error_msg = f"Error: {str(e)}"
        messages.append({"role": "assistant", "content": error_msg})
        return ["", error_msg, messages]


