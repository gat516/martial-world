--!strict
-- Shared behaviour for the pop-up list windows (herb pouch, seed picker):
-- open/close, and rebuilding rows from a hidden template row.

local ListWindow = {}

export type Row = {
	color: Color3,
	name: string,
	detail: string,
	count: number,
	onPress: () -> (),
}

function ListWindow.bindClose(window: Frame)
	(window:FindFirstChild("Close") :: TextButton).Activated:Connect(function()
		window.Visible = false
	end)
end

-- Replace the window's rows. buttonName is the action button inside the template row.
function ListWindow.fill(window: Frame, templateName: string, buttonName: string, rows: { Row })
	local list = window:FindFirstChild("List") :: ScrollingFrame
	local template = list:FindFirstChild(templateName) :: Frame
	for _, child in list:GetChildren() do
		if child:IsA("Frame") and child ~= template then
			child:Destroy()
		end
	end
	for i, r in rows do
		local row = template:Clone()
		row.Name = "Row"
		row.LayoutOrder = i
		row.Visible = true;
		(row:FindFirstChild("Swatch") :: Frame).BackgroundColor3 = r.color;
		(row:FindFirstChild("NameLabel") :: TextLabel).Text = r.name;
		(row:FindFirstChild("Detail") :: TextLabel).Text = r.detail;
		(row:FindFirstChild("CountLabel") :: TextLabel).Text = `x{r.count}`;
		(row:FindFirstChild(buttonName) :: TextButton).Activated:Connect(r.onPress)
		row.Parent = list
	end
end

return ListWindow
